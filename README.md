# spacecar
## Features
This tool will automatically prepare deals for a dataset in a streamlined way.
  a. Generate CAR file with IPLD
  b. Split files to fit into sector size
  c. Compute commP for piece\_size and piece\_cid
  d. Generate list of files contained in each CAR file
  e. Copy file to multiple hard drives for easier distribution via shipping
  f. Upload file to Backblaze B2 cloud storage for distribution via Internet
For faster processing, use tmpfs or fast NVME drive for temp folder and tmpdir.
## Installation
```bash
git clone https://github.com/xinaxu/spacecar.git
sudo apt install ruby
sudo gem install bundler
sudo bundle install
```

### Other dependencies
To calculate commP:
https://github.com/filedrive-team/go-graphsplit

To distribute data with BackBlaze cloud storage:
https://www.backblaze.com/b2/docs/quick\_command\_line.html

To compress the car file and distribute the compressed file instead:
`sudo apt install zstd`

### Usage
Create file config.yaml
```yaml
# Number of threads to process at the same time.
num_threads: 2
# Suffix of generated files
project_name: dataset
# Folder for the input dataset
input_folder: /mnt/dataset
# Output folder to put txt/cid/commp/car/zst files
output_folder: /mnt/output
# Temporary folder. Use tmpfs to get the best speed. Consumes up to 2 x sector_size.
temp_folder: /mnt/tmpfs
# Default deal size for 32GB deal
max_size_gb: 30
min_size_gb: 31
# Used to speed up graph split. Use tmpfs to get the best speed. Consumes exactly 2 x sector_size.
tmp_dir: /mnt/tmpfs
# 0 to disable compression. Otherwise, generate compressed car file using zstd.
compress_level: 12
# Also copy car file to below mounted path
copy:
# - /mnt/sda
# - /mnt/sdb
# Stop copying car files to mounted path if the disk available space is less than set value
disk_available_gb: 200
# Distribute the data via backblaze cloud storage. Use the below value as bucket name, assuming b2 authorize has been run.
copy_b2:
```
To run
```bash
ruby spacecar.rb
```

### TODO
1. implement keep\_input\_files: false
2. resume progress
