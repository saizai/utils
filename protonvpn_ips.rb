require 'rubygems'
gem 'netaddr', '=1.5.1'
require 'netaddr'
require 'json'
require 'open-uri'
vpnjson = JSON.parse(URI.open('https://api.protonmail.ch/vpn/logicals').read)
entries = vpnjson['LogicalServers'].map{|zz| zz['Servers'].map{|z| [z['EntryIP'], z['ExitIP']]}}.map{|z| z.map{|zz| zz[0]}}.flatten
exits = vpnjson['LogicalServers'].map{|zz| zz['Servers'].map{|z| [z['EntryIP'], z['ExitIP']]}}.map{|z| z.map{|zz| zz[1]}}.flatten

entry_only = entries - exits
exit_only = exits - entries
dual = (entries + exits - entry_only - exit_only).uniq

entries_cidr = NetAddr.merge(entry_only)
exits_cidr = NetAddr.merge(exit_only)
dual_cidr = NetAddr.merge(dual)
all_cidr = NetAddr.merge((entries + exits).uniq)

puts "\nEntry-only CIDRs"
p entries_cidr
puts "\nExit-only CIDRs"
p exits_cidr
puts "\nEntry/Exit CIDRs"
p dual_cidr
puts "\nAll CIDRs"
p all_cidr
