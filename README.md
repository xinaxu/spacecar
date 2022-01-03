# spacecar

## Installation
```bash
git clone
sudo apt install ruby
sudo gem install bundler
sudo bundle install
```

### Other dependencies
https://github.com/filedrive-team/go-graphsplit

### Usage
spacecar.config.yaml
```yaml
# Number of threads to process at the same time.
num_threads: 4
project_name: example
input_folder: /mnt/data/example/dataset
# Output folder to put txt/cid/commp/car/zst files
output_folder: /mnt/data/example/output
# Temporary folder. Use tmpfs to get the best speed. Consumes up to 2 x sector_size.
temp_folder: /mnt/data/example/temp
# Default deal size for 32GB deal
max_size_gb: 16.5
min_size_gb: 16
# Not used
keep_input_files: true
# Used to speed up graph split. Use tmpfs to get the best speed. Consumes exactly 2 x sector_size.
tmp_dir: /mnt/a65/blockchain/temp
# 0 to disable compression. Otherwise, generate compressed car file using zstd.
compress_level: 12
# Also copy car file to below mounted path
copy:
# Stop copying car files to mounted path if the disk available space is less than set value
disk_available_gb: 200
```
