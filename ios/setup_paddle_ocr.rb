#!/usr/bin/env ruby
# Script to add PaddleOCR files to the Xcode project
require 'xcodeproj'

project_path = File.join(__dir__, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# Get the Runner target
runner_target = project.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner_target

# Get the Runner group
runner_group = project.main_group.find_subpath('Runner', false)
raise 'Runner group not found' unless runner_group

# --- Add PaddleOCR source group ---
ocr_group = runner_group.find_subpath('PaddleOCR', false)
ocr_group.clear if ocr_group
ocr_group ||= runner_group.new_group('PaddleOCR', 'PaddleOCR')

source_files = %w[
  PaddleOcrPlugin.h
  PaddleOcrPlugin.mm
  pipeline.h
  pipeline.cc
  det_process.h
  det_process.cc
  rec_process.h
  rec_process.cc
  cls_process.h
  cls_process.cc
  db_post_process.h
  db_post_process.cc
  utils.h
  utils.cc
  timer.h
  clipper.hpp
  clipper.cpp
]

source_files.each do |name|
  ref = ocr_group.new_file(name)
  # Add compilable files to the target
  if name.end_with?('.cc', '.cpp', '.mm', '.m')
    runner_target.source_build_phase.add_file_reference(ref)
  end
end

# --- Add third-party group ---
thirdparty_group = runner_group.find_subpath('third-party', false)
thirdparty_group.clear if thirdparty_group
thirdparty_group ||= runner_group.new_group('third-party', 'third-party')

# Add PaddleLite static library
paddle_lib_group = thirdparty_group.new_group('PaddleLite', 'PaddleLite')
paddle_include_group = paddle_lib_group.new_group('include', 'include')
%w[paddle_api.h paddle_image_preprocess.h paddle_lite_factory_helper.h
   paddle_place.h paddle_use_kernels.h paddle_use_ops.h paddle_use_passes.h].each do |h|
  paddle_include_group.new_file(h)
end

paddle_lib_dir = paddle_lib_group.new_group('lib', 'lib')
lib_ref = paddle_lib_dir.new_file('libpaddle_api_light_bundled.a')
runner_target.frameworks_build_phase.add_file_reference(lib_ref)

# Add OpenCV framework
opencv_ref = thirdparty_group.new_file('opencv2.framework')
opencv_ref.last_known_file_type = 'wrapper.framework'
runner_target.frameworks_build_phase.add_file_reference(opencv_ref)

# --- Update build settings ---
header_search_paths = [
  '$(inherited)',
  '"$(SRCROOT)/Runner/PaddleOCR"',
  '"$(SRCROOT)/Runner/third-party/PaddleLite/include"',
  '"$(SRCROOT)/Runner/third-party"',
]

library_search_paths = [
  '$(inherited)',
  '"$(SRCROOT)/Runner/third-party/PaddleLite/lib"',
]

framework_search_paths = [
  '$(inherited)',
  '"$(SRCROOT)/Runner/third-party"',
]

other_ldflags = [
  '$(inherited)',
  '-lc++',
  '-lz',
]

runner_target.build_configurations.each do |config|
  bs = config.build_settings
  bs['HEADER_SEARCH_PATHS'] = header_search_paths
  bs['LIBRARY_SEARCH_PATHS'] = library_search_paths
  bs['FRAMEWORK_SEARCH_PATHS'] = framework_search_paths
  bs['OTHER_LDFLAGS'] = other_ldflags
  bs['CLANG_CXX_LANGUAGE_STANDARD'] = 'c++17'
  bs['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
  bs['ENABLE_BITCODE'] = 'NO'
  # Allow .cc files to be compiled as Obj-C++ when needed
  bs['OTHER_CPLUSPLUSFLAGS'] = '$(inherited) -fmodules -fcxx-modules'
end

project.save
puts "✅ Xcode project updated successfully!"
puts "   Added #{source_files.length} PaddleOCR source files"
puts "   Added PaddleLite static library"
puts "   Added OpenCV framework"
puts "   Updated header/library/framework search paths"
