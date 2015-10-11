# encoding: utf-8
require 'json'
require 'time'
require 'uri'
MAX_PLACEHOLDER = Time.now + (60*60*24*7)
CACHE_TTL = 20

def item_xml(options = {})
  <<-ITEM
  <item arg="#{options[:arg].encode(xml: :text)}" uid="#{options[:uid]}">
    <title>#{options[:title].encode(xml: :text)}</title>
    <subtitle>#{options[:subtitle].encode(xml: :text)}</subtitle>
    <icon>#{options[:icon]}</icon>
  </item>
  ITEM
end

cache_filename = "./cache/#{Time.now.to_i/CACHE_TTL}.json"
unless File.exist?(cache_filename)
  File.unlink *Dir.glob("./cache/*.json")
  system("osascript -l JavaScript omni_list.scpt > #{cache_filename}")
end
j = JSON.parse(open(cache_filename, external_encoding: 'UTF-8').read).map{|e|
  e.merge!({
    'dueDate' => (e['dueDate'] ? Time.parse(e['dueDate']) : nil),
    'deferDate' => (e['deferDate'] ? Time.parse(e['deferDate']) : nil)
  })
}

list = j.sort_by{|e| (e['dueDate'] ? e['dueDate'] : MAX_PLACEHOLDER ) }

def match?(word, query)
  return false unless word
  word.match(/#{query}/i)
end

queries = ARGV.first.dup.force_encoding('UTF-8').split(' ').map{|e| Regexp.escape(e) }

matches = list.select{|e| e['status'] == true }
queries.each do |query|
  matches = matches.select do |e|
    [
      match?(e['name'], query),
      match?(e['context'], query),
      match?(e['note'], query)
    ].any?
  end
end

def fmt_time(t)
  t.strftime("%m/%d %R")
end

matches = [{'name' => '(nothing...)'}] if matches.size == 0

items = matches.map do |elem|
  sub = ''
  sub << "[#{elem['context']}] " if elem['context']
  sub << "先: #{fmt_time(elem['deferDate'])} " if elem['deferDate']
  sub << "締: #{fmt_time(elem['dueDate'])} " if elem['dueDate']
  sub << "Note: #{elem['note']}" if elem['note'] && elem['note'].size != 0

  if elem['note'] =~ URI.regexp
    arg = "open '#{$&}'"
  else
    arg = 'open /Applications/OmniFocus.app'
  end

  item_xml({
    arg: arg,
    uid: 0,
    icon: '168CA675-5F85-4A9E-A871-5B3871DD0EAC.png',
    title: elem['name'],
    subtitle: sub,
  })
end.join

output = "<?xml version='1.0'?>\n<items>\n#{items}</items>"

puts output
