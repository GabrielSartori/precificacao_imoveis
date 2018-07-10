# Pacotes 
require(rgdal)
require(sp)
require(spdep)
require(rgeos)
require(maptools)


# Mapas - Base de Dados
# http://www.leg.ufpr.br/doku.php/disciplinas:geoesalq:historico?s[]=bairros -
# Baixar os três arquivos (bairros.shp bairros.shx bairros.dbf)

cwb_pj <- readOGR(dsn = '/home/gabriel/Suporte/Hackthons/BlueHacks/Scripts/maisparana/gabriel', 
                  layer = 'bairros', 
                  verbose = FALSE, encoding = 'Latin1')  

proj4string(cwb_pj) <- CRS("+proj=utm +zone=22 +south") 

# Unindo Base de Dados
cwb_pj <- gBuffer(cwb_pj, byid = TRUE, width = 0)
cwb_union <- unionSpatialPolygons(cwb_pj, rep(1, 75))
df <- data.frame(id = 1)
cwb_union <- SpatialPolygonsDataFrame(cwb_union, df)
# writeOGR(cwb_union, "cwb_union_geojson", layer = "cwb_grid", driver = "GeoJSON")

# Criar um Grid
cs <- c(3.28084, 3.28084)*200
grdpts <- makegrid(cwb_union, cellsize = cs)

spgrd <- SpatialPoints(grdpts, proj4string = CRS(proj4string(cwb_union)))

spgrdWithin <- SpatialPixels(spgrd[cwb_union,])
plot(spgrdWithin)

cwb_grid <- as(spgrdWithin, "SpatialPolygons")
cwb_grid_iqa <- as(spgrdWithin, "SpatialGrid")


row.names(cwb_grid) <- names(cwb_grid) 
df <- data.frame(id = names(cwb_grid))
rownames(df) <- names(cwb_grid)

spdf <- SpatialPolygonsDataFrame(cwb_grid, data = df)

spdf <-
  spTransform(spdf,  CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))

# writeOGR(spdf, "cwb_geojson", layer="cwb_grid", driver = "GeoJSON")
# grd_cwb <- readOGR(dsn = "cwb_geojson", layer = "OGRGeoJSON")
# Salvar em geojson

# Contagem de Pizzaria por bairro
load("/home/gabriel/Suporte/DataScience/Meetup/Curitiba/app_13_03/variaveis/pizza.rda")
load("/home/gabriel/Suporte/DataScience/Meetup/Curitiba/app_13_03/variaveis/coord.rda")

clientes$NUMERO <- clientes$NUMERO %>%
  as.numeric()

# clientes$end_comp <- paste(clientes$ENDERECO, clientes$NUMERO)

# Geocode
# coord_cliente <- geocode(clientes$end_comp)

coord_cliente <- coord_cliente %>% 
  na.omit()

# save(coord_cliente, file="coord.rda")
plot(spdf)
points(coord_cliente[,1], coord_cliente[,2], col = 'red')

# TRansformar arquivo em Spatial Points Data.frame

sp_cliente <- SpatialPoints(coord_cliente)
proj4string(sp_cliente) <- proj4string(spdf)

# p <- spsample(spdf, n=300, type="random")

sp_cliente <- SpatialPointsDataFrame(sp_cliente, data.frame(id = 1:555))
# rownames(sp_cliente)
# Contar por ID
require(GISTools)

poly.counts(sp_cliente, spdf) -> n_pizza

n_pizza <- n_pizza %>% 
  data.frame() %>% 
  add_rownames("id")

# Unindo Dados
spdf@data <- spdf@data %>% 
  left_join(n_pizza, by = 'id')

names(spdf@data)[2] <- "n_pizza" 

# Ler arquivo de imóveis

load("/home/gabriel/Suporte/DataScience/Meetup/Curitiba/app_13_03/variaveis/imoveis-geo.rda")
head(imoveis)

table(imoveis$neighborhoodName)
plot(spdf)
points(imoveis$lon, imoveis$lat)

sp_imoveis <- SpatialPointsDataFrame(imoveis[,c("lon", "lat")], imoveis[,1:8])
proj4string(sp_imoveis) <- "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"
sp_imoveis_join <- spatialEco::point.in.poly(sp_imoveis, spdf)
head(sp_imoveis_join)

# Calculando Preço médio do m^2 por área

id_m2 <- sp_imoveis_join@data %>% 
  group_by(id) %>% 
  summarise(mean(m2))

# str(sp_imoveis_join@data)
sp_imoveis_join@data$priceValue <- as.numeric(sp_imoveis_join@data$priceValue)

preco <- sp_imoveis_join@data %>% 
  group_by(id) %>% 
  summarise(area_all = sum(area, na.rm = TRUE),
            preco_all = sum(priceValue, na.rm = TRUE),
                            n_imo = length(area)) %>% 
  mutate(media_area = preco_all/area_all)

# sp_imoveis_join@data %>% 
#   filter(id == "g79" )
# 
# preco %>% 
#   filter(id == "g79" )

# POrcentagem Casa
preco <- sp_imoveis_join@data %>%
  filter(propertyTypeName == "Apartamento") %>%
  group_by(id) %>%
  count() %>%
  right_join(preco, by = "id") %>%
  mutate(perc_ap = n/n_imo)

preco$n[is.na(preco$n)] <- 0
preco$perc_ap[is.na(preco$perc_ap)] <- 0

# Unindo Base de Dados
spdf@data <- spdf@data %>% 
  left_join(preco, by = 'id') 

spdf@data <- spdf@data %>%
  left_join(id_m2, by = 'id')

names(spdf@data) <- c("id", "n_pizza", "n_ap", "area_all", 
                      "preco_all", "n_imo", "preco_area", "perc_ap", "m2") 
# Salvar em Geojson

writeOGR(spdf, "cwb_imoveis_geojson", layer = "cwb_imoveis", driver = "GeoJSON")
