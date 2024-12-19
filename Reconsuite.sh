#!/bin/bash

# Normalize input to remove trailing slashes
url=$(echo "$1" | sed 's:/*$::')

# Ensure the target domain is provided
if [ -z "$url" ]; then
    echo "Usage: $0 <target_domain>"
    exit 1
fi

# Check if required tools are installed
for tool in assetfinder amass httprobe; do
    if ! command -v $tool &> /dev/null; then
        echo "Error: $tool is not installed. Install it and try again."
        exit 1
    fi
done

# Setup directory structure
if [ ! -d "$url" ]; then
    mkdir "$url"
fi

if [ ! -d "$url/recon" ]; then
    mkdir "$url/recon"
fi

log_file="$url/recon/script.log"

# Log start of the process
echo "[INFO] Starting subdomain enumeration for $url" | tee -a "$log_file"

# Check if final.txt already exists
final_output="$url/recon/final.txt"
if [ -f "$final_output" ]; then
    echo "[!] $final_output already exists. Overwrite? (y/n)"
    read -r choice
    if [[ "$choice" != "y" ]]; then
        echo "[INFO] Exiting without overwriting." | tee -a "$log_file"
        exit 1
    fi
    # Clear the file if overwrite is selected
    > "$final_output"
fi

# Run assetfinder and save results
assetfinder_output="$url/recon/assetfinder.txt"
echo "[+] Harvesting subdomains with assetfinder" | tee -a "$log_file"
assetfinder "$url" | grep "$url" > "$assetfinder_output"

# Run amass and save results
amass_output="$url/recon/amass.txt"
echo "[+] Enumerating subdomains with Amass" | tee -a "$log_file"
amass enum -d "$url" | cut -d ' ' -f1 | grep $url > "$amass_output"

# Combine results and remove duplicates
echo "[+] Combining results and removing duplicates" | tee -a "$log_file"
cat "$assetfinder_output" "$amass_output" | sort -u > "$final_output"
echo "[INFO] Combined subdomains saved to $final_output" | tee -a "$log_file"

# Check live subdomains with httprobe
live_output="$url/recon/live_subdomains.txt"
if command -v httprobe &> /dev/null; then
    echo "[+] Checking live subdomains with httprobe" | tee -a "$log_file"
    cat "$final_output" | httprobe -s -p https:443 | sed 's/https\?:\/\///' | tr -d ':443' > "$live_output"
    echo "[INFO] Live subdomains saved to $live_output" | tee -a "$log_file"
else
    echo "[WARNING] httprobe not found. Skipping live subdomain check." | tee -a "$log_file"
fi

# Use gowitness to screenshot live subdomains
gowitness_output_dir="$url/recon/gowitness"
echo "[+] Capturing screenshots with gowitness" | tee -a "$log_file"
if ! command -v gowitness &> /dev/null; then
    echo "[ERROR] gowitness is not installed. Install it and try again." | tee -a "$log_file"
    exit 1
fi

# Ensure gowitness output directory exists
if [ ! -d "$gowitness_output_dir" ]; then
    mkdir "$gowitness_output_dir"
fi

# Run gowitness against the live subdomains
gowitness file -f "$live_output" -P "$gowitness_output_dir"
echo "[INFO] gowitness screenshots saved to $gowitness_output_dir" | tee -a "$log_file"

# Completion message
echo "[INFO] Subdomain enumeration complete. Results saved in $final_output" | tee -a "$log_file"
