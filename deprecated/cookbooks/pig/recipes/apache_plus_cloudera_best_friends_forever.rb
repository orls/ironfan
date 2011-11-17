#
# Cookbook Name::       pig
# Description::         Apache Plus Cloudera Best Friends Forever
# Recipe::              apache_plus_cloudera_best_friends_forever
# Author::              Philip (flip) Kromer - Infochimps, Inc
#
# Copyright 2009, Infochimps, Inc.
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

#
# Install pig from latest release
#
#   puts pig tarball into /usr/local/src/pig-xxx
#   expands it into /usr/local/share/pig-xxx
#   and links that to /usr/local/share/pig
#

pig_install_pkg      = File.basename(node[:pig][:install_url])
pig_install_dir      = pig_install_pkg.gsub(%r{(?:-bin)?\.tar\.gz}, '')
pig_hbase_patch_name = File.basename(node[:pig][:pig_hbase_patch])
pig_zookeeper_jar    = File.basename(node[:pig][:zookeeper_jar_url])

#
# Put our own version of the pig executable in place
#
template "/usr/local/share/pig/bin/pig" do
  owner "root"
  mode "0755"
  source "pig.erb"
end

#
# Pig configuration
#
template "/usr/local/share/pig/conf/pig.properties" do
  owner "root"
  mode "0644"
  source "pig.properties.erb"
end

#
# Fetch patch for using pig 0.8 with hbase 0.89
#
remote_file "/usr/local/share/pig/#{pig_hbase_patch_name}" do
  source    node[:pig][:pig_hbase_patch]
  mode      "0644"
  action :create
end

#
# Apply patch forcefully but skip if it's already applied
#
bash 'apply pig 0.8 + hbase 0.89 patch' do
  user 'root'
  cwd  '/usr/local/share/pig'
  code "patch -fN --ignore-whitespace -p0 < #{pig_hbase_patch_name}; true"
end

#
# Need to move existing lib dir out of the way
#
script 'move some pig jars around' do
  interpreter "bash"
  user       "root"
  cwd        "/usr/local/share/pig"
  code <<-EOH
  mv lib lib-0.20.6
  mkdir lib
  cp lib-0.20.6/automaton.jar lib/
  cp -r lib-0.20.6/jdiff lib/
  mv pig-0.8.0-core.jar lib-0.20.6/
  EOH
  not_if{File.exists?("/usr/local/share/pig/lib-0.20.6")}
end

script 'fetch fucked up apache hbase jar because pig wont compile without its extra special secret version and some people dont know all the fucked up places that ant looks for it' do
  interpreter "bash"
  user        "root"
  cwd         "/usr/local/share/pig/lib"
  code <<-EOH
  hbase_version=`grep -e "^hbase.version=" ../ivy/libraries.properties |sed 's/hbase.version=//g'`
  wget --no-check-certificate https://repository.apache.org/content/repositories/snapshots/org/apache/hbase/hbase/0.89.0-SNAPSHOT/hbase-${hbase_version}.jar
  wget --no-check-certificate https://repository.apache.org/content/repositories/snapshots/org/apache/hbase/hbase/0.89.0-SNAPSHOT/hbase-${hbase_version}-tests.jar
  EOH
  not_if{ File.exists?("/usr/local/share/pig/pig.jar")}
end

#
# Fetch updated zookeeper jar so it's in the pig classpath
#
remote_file "/usr/local/share/pig/lib/#{pig_zookeeper_jar}" do
  source    node[:pig][:zookeeper_jar_url]
  mode      "0644"
  action    :create
end

#
# Rebuild pig jar without hadoop
#
bash 'build pig without apache hadoop jars stuffed in' do
  user 'root'
  cwd  '/usr/local/share/pig'
  environment 'JAVA_HOME' => node[:pig][:java_home]
  code "ant jar-withouthadoop"
  not_if{ File.exists?("/usr/local/share/pig/pig-withouthadoop.jar") || File.exists?("/usr/local/share/pig/pig.jar")}
end

#
# Rename pig jar and remove build dir
#
script 'cleanup build and rename jar' do
  interpreter "bash"
  user       "root"
  cwd        "/usr/local/share/pig"
  code <<-EOH
  mv pig-withouthadoop.jar pig.jar
  rm -r build
  rm -r lib/hbase*
  EOH
  not_if{File.exists?("/usr/local/share/pig/pig.jar")}
end