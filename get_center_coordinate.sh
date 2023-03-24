#!/bin/bash

# This script will find the geographical center of a geotif image and print it
# out. The center coordinate is necessary for Map Overlay creation. 		
#										
# If no coordinate is found, or if errors are printed, it is likely that the	
# tif metadata is insufficient or is in an unrecognized format. Comapare the	
# outputs of gdalinfo $file between the new tif image and a known working one.	

# Check if gdalinfo and gdaltransform are installed
if ! command -v gdalinfo &> /dev/null || ! command -v gdaltransform &> /dev/null
then
    echo "gdalinfo and gdaltransform not found. Please install the GDAL library: "
    echo "\$ apt install gdal-bin"
    exit
fi

# Get the input GeoTiff file name from command line argument
if [ -z "$1" ]
then
    echo "Please provide the input GeoTiff file name as argument."
    exit
fi
input_file="$1"


# Get the center coordinate from the GeoTiff file using gdalinfo
geo_tmp=$(gdalinfo $input_file | grep "Center")

geo_tmp=$(echo $geo_tmp | grep -oP '\(([^)]+)\)' | head -1 | tr -d '()')


# Find the coordinate system used in the geotif
epsg_number=$(gdalinfo $input_file | grep '^    ID\[\"EPSG\"\,' | grep -oP '\d+')
echo "Using EPSG-$epsg_number"


# Convert the center coordinate from projected to geographic coordinate system
geo_tmp=$(gdaltransform -s_srs epsg:$epsg_number -t_srs epsg:4326 <<< $geo_tmp) 

geo_tmp=$(echo $geo_tmp | sed 's/ *$//g')

geographic_coordinate=$(echo $geo_tmp | awk -F' ' '{print $2 " " $1}')


# Print the geographic coordinate
echo -e "Geographic center coordinate of $input_file: \n$geographic_coordinate"
