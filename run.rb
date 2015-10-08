require 'json'
require 'time'
require 'uri'
MAX_PLACEHOLDER = Time.now + (60*60*24*7)

def item_xml(options = {})
  <<-ITEM
  <item arg="#{options[:arg].encode(xml: :text)}" uid="#{options[:uid]}">
    <title>#{options[:title].encode(xml: :text)}</title>
    <subtitle>#{options[:subtitle].encode(xml: :text)}</subtitle>
    <icon>#{options[:icon]}</icon>
  </item>
  ITEM
end

js_str =<<JS
of = Library('OmniFocus')
tasks = of.allTasks()
names = []
tasks.forEach(function(e){
  var ctx = (e.context() ? e.context.name() : null)
  var obj = {
    id: e.id(),
    name: e.name(),
    context: ctx,
    deferDate: e.deferDate(),
    dueDate: e.dueDate(),
    note: e.note(),
  }
  names.push(obj)
})
JSON.stringify(names)
JS

j = ''
IO.popen("osascript -l JavaScript -e \"#{js_str}\" ", external_encoding: 'UTF-8'){|io| j = io.read }
j = JSON.parse(j).map{|e|
  e.merge!({
    'dueDate' => (e['dueDate'] ? Time.parse(e['dueDate']) : nil),
    'deferDate' => (e['deferDate'] ? Time.parse(e['deferDate']) : nil)
  })
}

list = j.sort_by{|e| (e['dueDate'] ? e['dueDate'] : MAX_PLACEHOLDER ) }

def match?(word, query)
  word.match(/#{query}/i)
end

queries = ARGV.first.split(' ').map{|e| Regexp.escape(e) }

matches = list
queries.each do |query|
  matches = matches.select { |e| match?(e['name'], query) }
end

def fmt_time(t)
  t.strftime("%m/%d %R")
end

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
