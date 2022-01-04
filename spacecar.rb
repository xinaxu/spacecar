#!/usr/bin/ruby
require 'yaml'
require 'fileutils'
require 'pathname'
require 'json'
require 'parallel'
require 'sys/filesystem'
config_file = ARGV[0] || 'spacecar.config.yaml'
config = YAML.load(File.read(config_file))
@num_threads = config['num_threads']
@input= config['input_folder']
@output= config['output_folder']
@temp= config['temp_folder']
@max= (config['max_size_gb'] * 1024 * 1024 * 1024).to_i
@min= (config['min_size_gb'] * 1024 * 1024 * 1024).to_i
@keep = config['keep_input_files']
@name = config['project_name']
@tmp_dir = config['tmp_dir']
@compress = config['compress_level']
@copy = config['copy']
@disk_available = config['disk_available_gb']
@b2 = config['copy_b2']

unless File.directory? @input
  raise "input folder '#{@input}' does not exist or is not a directory"
end

FileUtils.mkdir_p(@output)
FileUtils.rm_rf Dir.glob(File.join(@temp, '*'))

def generate_groups(paths)
  groups = []
  group = []
  size = 0
  paths.each do |path|
    next unless path.file?
    remaining = path.size
    start = 0
    index = 0
    if size + path.size > @max
      loop do
        group << [path, start, @max - size, index]
        groups << group
        group = []
        remaining -= @max - size
        start += @max - size
        size = 0
        index += 1
        break if remaining <= @max
      end
    end
    if remaining + size < @min
      group << [path, start, remaining, index] 
      size += remaining
    elsif remaining + size <= @max
      group << [path, start, remaining, index]
      groups << group
      group = []
      size = 0
    end
  end
  groups
end

puts "== Processing the source folder"
paths = Pathname.glob(File.join(@input, '**', '*'))
groups = generate_groups(paths)

puts "== Generating Cars with #{@num_threads} threads"
Parallel.each_with_index(groups, in_threads: @num_threads) do |group, index|
  commp_file = "#{@output}/#{@name}.#{index}.commp"
  if File.exists?(commp_file) && File.size(commp_file) > 10
    puts "== [#{index}] Skipped"
    next
  end
  puts "== [#{index}] Transfering data to temp folder"
  temp = File.join(@temp, index.to_s)
  temp_ipfs = File.absolute_path(File.join(@temp, index.to_s, 'ipfs'))
  temp_dataset = File.join(@temp, index.to_s, 'dataset')
  FileUtils.mkdir_p(temp_ipfs)
  FileUtils.mkdir_p(temp_dataset)
  group.each do |path, offset, length, index|
    relative = path.relative_path_from(@input)
    target = Pathname.new(temp_dataset).join(relative)
    FileUtils.mkdir_p(target.dirname.to_s)
    target = target.to_s
    if offset != 0 || length != path.size
      target = "%s.%04d" % [target, index]
    end
    IO.copy_stream(path.to_s, target, length, offset)
  end
  puts "== [#{index}] Adding temp folder to IPFS"
  system("IPFS_PATH=#{temp_ipfs} ipfs init")
  system("IPFS_PATH=#{temp_ipfs} ipfs config --json Experimental.FilestoreEnabled true")
  result = `IPFS_PATH=#{temp_ipfs} ipfs add -r -p=false --pin=false --nocopy #{temp_dataset}`
  cid = result.lines[-1].split(' ', 3)[1]

  temp_car = "#{@temp}/#{@name}.#{index}.car"
  cid_file = "#{@output}/#{@name}.#{index}.cid"
  txt_file = "#{@output}/#{@name}.#{index}.txt"
  commp_file = "#{@output}/#{@name}.#{index}.commp"
  zst_file = "#{@output}/#{@name}.#{index}.car.zst"
  File.write(txt_file, result)
  File.write(cid_file, cid)
  puts "== [#{index}] Generating car file"
  system("IPFS_PATH=#{temp_ipfs} ipfs dag export #{cid} > #{temp_car}")
  puts "== [#{index}] Distributing car file"
  threads = []
  threads.push(Thread.new{FileUtils.cp(temp_car, @output)})
  threads.push(Thread.new{system("TMPDIR=#{File.absolute_path(@tmp_dir)} graphsplit commP #{temp_car} > #{commp_file}")})
  if @compress > 0
    threads.push(Thread.new{
      system("zstdmt -f -#{@compress} #{temp_car} -o #{zst_file}")
      if @b2
        threads.push(Thread.new{system("b2 upload-file --quiet --threads 16 #{@b2} #{zst_file} #{@name}.#{index}.car.zst")})
      end
    })
  else
    if @b2
      threads.push(Thread.new{system("b2 upload-file --quiet --threads 16 #{@b2} #{temp_car} #{@name}.#{index}.car")})
    end
  end
  if @copy
    @copy.each do |dst|
      threads.push(Thread.new do
        loop do
          if File.writable?(dst) && Sys::Filesystem.mounts.any?{|mount| mount.mount_point == dst}
            dst_stat = Sys::Filesystem.stat(dst)
            if dst_stat.block_size * dst_stat.blocks_available / 1024 / 1024 / 1024 >= @disk_available
              break
            end
          end
          puts "Please replace disk #{dst} and make sure it's writable and has at least #{@disk_available} GB space"
          sleep 60
        end
        FileUtils.cp(temp_car, dst)
      end)
    end
  end
  threads.push(Thread.new{
    FileUtils.rm_rf(File.join(@temp, index.to_s))
  })
  threads.each{|thread| thread.join}
  FileUtils.rm(temp_car)
end
