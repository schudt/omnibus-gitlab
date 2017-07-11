#
# Copyright:: Copyright (c) 2017 GitLab Inc.
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

repmgr_helper = RepmgrHelper.new(node)
replication_user = node['repmgr']['user']
repmgr_conf = "#{node['gitlab']['postgresql']['dir']}/repmgr.conf"

node.default['gitlab']['postgresql']['custom_pg_hba_entries']['repmgr'] = repmgr_helper.pg_hba_entries

# node number needs to be unique (to the cluster) positive 32 bit integer.
# If the user doesn't provide one, generate one ourselves.
node_number = node['repmgr']['node_number'] ||
  Digest::MD5.hexdigest(node['fqdn']).unpack('L').first
template repmgr_conf do
  source 'repmgr.conf.erb'
  owner node['gitlab']['postgresql']['username']
  variables(
    node['repmgr'].to_hash.merge(
      node_name: node['repmgr']['node_name'] || node['fqdn'],
      host: node['repmgr']['host'] || node['fqdn'],
      node_number: node_number
    )
  )
end

postgresql_user replication_user do
  options %w(SUPERUSER)
end

postgresql_database node['repmgr']['database'] do
  owner replication_user
  notifies :run, "execute[register repmgr master node]"
end

execute 'register repmgr master node' do
  command "/opt/gitlab/embedded/bin/repmgr -f #{repmgr_conf} master register"
  user node['gitlab']['postgresql']['username']
  action :nothing
end