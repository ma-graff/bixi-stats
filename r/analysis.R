library(data.table)  # Efficient data handling
library(ggplot2)     # Visualization
library(lubridate)   # Easier handling of dates and times
library(dplyr)
library(scales)  # Needed for formatting numbers

# Exploring the data
df <- fread("/Users/matt/Documents/BixiData.csv")  # Read the 2024 data
head(df)

### Bike Share Usage by Time of Day & Season
df <- df %>%
  mutate(
    start_time = as.POSIXct(STARTTIMEMS / 1000, origin = "1970-01-01", tz = "America/Toronto"),
    hour = hour(start_time),  # Extract hour of the day
    month = month(start_time),  # Extract month
    season = case_when(
      month %in% c(12, 1, 2) ~ "Winter",
      month %in% c(3, 4, 5) ~ "Spring",
      month %in% c(6, 7, 8) ~ "Summer",
      month %in% c(9, 10, 11) ~ "Fall"
    )
  )

hourly_usage <- df %>%
  group_by(season, hour) %>%
  summarise(trips = n(), .groups = 'drop')

ggplot(hourly_usage, aes(x = hour, y = trips, color = season)) +
  geom_line(size = 1) +
  labs(
    title = "Bike Share Usage by Hour of Day & Season",
    x = "Hour of the Day (24h)",
    y = "Number of Trips",
    color = "Season"
  ) +
  theme_minimal() +
  scale_x_continuous(breaks = seq(0, 23, by = 2))  # Show every 2 hours for clarity


### leaflet map
library(sf)
library(leaflet)


# Count trips per station
start_counts <- df %>%
  group_by(STARTSTATIONNAME, STARTSTATIONLATITUDE, STARTSTATIONLONGITUDE) %>%
  summarise(trip_count = n()) %>%
  arrange(desc(trip_count))

# Remove rows with missing latitude or longitude values
start_counts <- start_counts %>%
  filter(!is.na(STARTSTATIONLATITUDE) & !is.na(STARTSTATIONLONGITUDE))

# Interactive Map using Leaflet
leaflet(start_counts) %>%
  addProviderTiles("CartoDB.DarkMatter") %>%  # Use CartoDB Positron for a white basemap
  addCircleMarkers(
    ~STARTSTATIONLONGITUDE, ~STARTSTATIONLATITUDE, 
    radius = ~sqrt(trip_count) / 50, 
    color = ~colorNumeric("YlOrRd", trip_count)(trip_count),  # Temperature-like scale (Yellow to Red)
    fillOpacity = 0.6, 
    popup = ~paste(STARTSTATIONNAME, "<br>Trips started here:", trip_count)
  ) %>%
  addLegend("bottomright", 
            pal = colorNumeric("YlOrRd", start_counts$trip_count), 
            values = start_counts$trip_count, 
            title = "Trip Started Count") %>%
  setView(lng = -73.5673, lat = 45.5017, zoom = 12)  # Set the map center (Montreal) and zoom level

### common routes
# Count the occurrences of each route (start station to end station)
route_counts <- df %>%
  count(STARTSTATIONNAME, ENDSTATIONNAME) %>%
  arrange(desc(n))  # Sort by the count in descending order

# Display the top 10 most common routes
head(route_counts, 10)

library(plotly)

# Create an interactive plot
plot_ly(route_counts[1:10, ], 
        x = ~reorder(paste(STARTSTATIONNAME, "->", ENDSTATIONNAME), -n),
        y = ~n,
        type = 'bar',
        hovertext = ~paste(STARTSTATIONNAME, " -> ", ENDSTATIONNAME, '<br>Trips: ', n),
        hoverinfo = 'text',
        marker = list(color = 'rgb(0, 102, 204)', line = list(color = 'rgb(0, 51, 102)', width = 1))) %>%
  layout(title = "Top 10 Most Commonly Traveled Routes",
         xaxis = list(title = "Route", tickangle = 45, showticklabels = FALSE),  # Hide x-axis labels
         yaxis = list(title = "Number of Trips"),
         showlegend = FALSE)

