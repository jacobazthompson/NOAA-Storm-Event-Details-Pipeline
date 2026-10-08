# NOAA Storms Pipeline

A one-command pipeline that downloads a year of NOAA Storm Events data, converts it to GeoParquet, and lands it ready for analysis in DuckDB, GeoPandas, or QGIS.

## What it does

`pipeline.sh` takes a year (default: 2024), pulls the raw `details` file from NOAA's public archive, decompresses it, and converts it to a single GeoParquet file at `data/processed/storms_{YEAR}.parquet`.

Total runtime: about 90 seconds for a typical year on a home internet connection.

## The data

- **Source:** [NOAA Storm Events Database](https://www.ncei.noaa.gov/data/storm-events/)
- **License:** Public domain (US federal data)
- **What's in it:** every recorded storm event in the United States for the given year, including type, location, and damages

## How to run it

Requires GDAL (for `ogr2ogr`) and standard Unix utilities (`curl`, `gunzip`).

```bash
git clone https://github.com/jacobazthompson/NOAA-Storm-Event-Details-Pipeline
cd NOAA-Storm-Event-Details-Pipeline
chmod +x pipeline.sh
./pipeline.sh
```

To run for a specific year:

```bash
./pipeline.sh (year)
```

## What I learned

In order to create this module, I learned about picking and utilizing the right shell language for the job, integrating python into scripts through a virtual environmnet, and adding differnt libraries as a pre-requisite in the script that directly communicate with geodata. I also included a ledger that tracks directly how I observed a problem and approached it in (logic_process_ledger.txt). I initially downloaded OSGeo4W and added it as a shell language as I am more familiar with powershell, but pivoted to WSL for it to be written in a universally-accessible language. I learned about how to use WSL, and simple linux commands to create a basic working pipeline. As I ran into issues such as dynamic created dates within the NOAA download site and the downloaded compressed files not unzipping, I sourced agentic solutions, which assisted me in creating a web scraper to alleviate the need for a rigid create date, expedited arbitrary and proprietary arguements to communicate with libraries and packages, and implement if/else statements to reduce download redundancies. I also learned how to optimize a script for pushing to github, and file management directly through the terminal. 

A huge thanks to Matt Forrest for assistance in the providing the foundational knowledge to get started, and for providing the prompt.

## Stack

- bash
- curl
- GDAL / ogr2ogr
- GeoParquet
