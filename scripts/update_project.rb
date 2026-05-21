#!/usr/bin/env ruby
require 'xcodeproj'

def usage
  puts "Usage: ruby update_project.rb <project_path> <action> <target_name> <file_path>"
  puts ""
  puts "Actions:"
  puts "  add_swift       - Add a Swift file to the target's Compile Sources"
  puts "  remove_objc     - Remove a .m file from Compile Sources (keeps file reference)"
  puts "  remove_file     - Remove file reference entirely from project"
  puts "  remove_header   - Remove a .h file from Headers build phase"
  puts ""
  puts "Example:"
  puts "  ruby update_project.rb libs/SmartStore/SmartStore.xcodeproj SmartStoreTests add_swift SmartStoreTests/MyNewTest.swift"
  exit 1
end

usage if ARGV.length < 4

project_path = ARGV[0]
target_name = ARGV[1]
action = ARGV[2]
file_path = ARGV[3]

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }

unless target
  puts "ERROR: Target '#{target_name}' not found in #{project_path}"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end

case action
when 'add_swift'
  # Find or create group for the file
  path_components = file_path.split('/')
  file_name = path_components.last
  group_path = path_components[0...-1]

  # Navigate to the correct group
  current_group = project.main_group
  group_path.each do |component|
    found = current_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.path == component }
    if found
      current_group = found
    else
      found = current_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == component }
      if found
        current_group = found
      else
        current_group = current_group.new_group(component, component)
      end
    end
  end

  # Check if file already exists in project
  existing = current_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) && c.path == file_name }
  if existing
    # Make sure it's in the compile sources
    build_file = target.source_build_phase.files.find { |f| f.file_ref == existing }
    unless build_file
      target.source_build_phase.add_file_reference(existing)
      puts "Added existing reference '#{file_name}' to #{target_name} compile sources"
    else
      puts "File '#{file_name}' already in #{target_name} compile sources"
    end
  else
    file_ref = current_group.new_reference(file_name)
    file_ref.last_known_file_type = 'sourcecode.swift'
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added '#{file_path}' to #{target_name} compile sources"
  end

when 'remove_objc'
  # Find the file reference and remove from compile sources only
  file_name = File.basename(file_path)
  removed = false

  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path == file_name
      target.source_build_phase.files.delete(build_file)
      puts "Removed '#{file_name}' from #{target_name} compile sources"
      removed = true
      break
    end
  end

  unless removed
    puts "WARNING: '#{file_name}' not found in #{target_name} compile sources"
  end

when 'remove_file'
  # Remove file reference entirely
  file_name = File.basename(file_path)
  removed = false

  project.files.each do |file_ref|
    if file_ref.path == file_name
      # Remove from any build phases first
      target.build_phases.each do |phase|
        phase.files.each do |build_file|
          if build_file.file_ref == file_ref
            phase.files.delete(build_file)
          end
        end
      end
      file_ref.remove_from_project
      puts "Removed '#{file_name}' entirely from project"
      removed = true
      break
    end
  end

  unless removed
    puts "WARNING: '#{file_name}' not found in project"
  end

when 'remove_header'
  file_name = File.basename(file_path)
  removed = false

  target.headers_build_phase&.files&.each do |build_file|
    if build_file.file_ref && build_file.file_ref.path == file_name
      target.headers_build_phase.files.delete(build_file)
      puts "Removed '#{file_name}' from #{target_name} headers phase"
      removed = true
      break
    end
  end

  unless removed
    puts "WARNING: '#{file_name}' not found in #{target_name} headers phase (may not exist)"
  end

else
  puts "ERROR: Unknown action '#{action}'"
  usage
end

project.save
puts "Project saved: #{project_path}"
