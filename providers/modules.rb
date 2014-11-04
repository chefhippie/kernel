#
# Cookbook Name:: kernel
# Provider:: modules
#
# Copyright 2013-2014, Thomas Boerger <thomas@webhippie.de>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "chef/dsl/include_recipe"
include Chef::DSL::IncludeRecipe

action :create do
  return unless node["platform_family"] == "suse"

  template module_file do
    mode 0644
    owner "root"
    group "root"

    cookbook "kernel"
    source "module.conf.erb"

    variables(
      "modules" => new_resource.modules
    )
  end

  template options_file do
    mode 0644
    owner "root"
    group "root"

    cookbook "kernel"
    source "options.conf.erb"

    variables(
      "options" => new_resource.options
    )

    not_if do
      new_resource.options.empty?
    end
  end

  kernel_modules new_resource.alias do
    modules new_resource.modules
    action :load
  end

  new_resource.updated_by_last_action(true)
end

action :load do
  return unless node["platform_family"] == "suse"

  new_resource.modules.each do |name|
    bash "kernel_load_#{name}" do
      code <<-EOH
        /sbin/modprobe #{name}
      EOH

      action :run

      only_if do
        `/sbin/lsmod | grep #{name} | wc -l`.strip == "0"
      end
    end
  end

  new_resource.updated_by_last_action(true)
end

action :delete do
  return unless node["platform_family"] == "suse"

  kernel_modules new_resource.alias do
    modules new_resource.modules
    action :unload
  end

  file options_file do
    action :delete
  end

  file module_file do
    action :delete
  end

  new_resource.updated_by_last_action(true)
end

action :unload do
  return unless node["platform_family"] == "suse"

  new_resource.modules.each do |name|
    bash "kernel_unload_#{name}" do
      code <<-EOH
        /sbin/rmmod #{name}
      EOH

      action :run

      not_if do
        `/sbin/lsmod | grep #{name} | wc -l`.strip == "0"
      end
    end
  end

  new_resource.updated_by_last_action(true)
end

def module_file
  ::File.join(node["kernel"]["modules_dir"], "#{new_resource.alias}.conf")
end

def options_file
  ::File.join(node["kernel"]["options_dir"], "80-#{new_resource.alias}.conf")
end
