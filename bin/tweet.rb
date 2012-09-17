#!/usr/bin/ruby

require "rubygems"
require "bundler/setup"
require "twitter"
require 'optparse'
require 'pp'
require 'oj'
require 'mail'
require 'uri'
require 'erb'

options = {}

optparse = OptionParser.new do |opts|

	opts.banner = "Usage: #{__FILE__} -c CONFIG_FILE [options]"

	opts.separator ""
	opts.separator "Required options:"

	options[:config_file] = nil;
	opts.on("-c", "--config CONFIG_FILE",
	"configuration file to use") do |user|
		options[:config_file] = user
	end

	opts.separator ""
	opts.separator "Common options:"

	options[:verbose] = false
	opts.on( '-v', '--verbose', 'Output more information' ) do
		options[:verbose] = true
	end

	options[:dryrun] = false
	opts.on( '-n', '--dry-run', "Don't send any tweets" ) do
		options[:dryrun] = true
	end

	opts.on_tail('-h', '--help', 'Display this help') do 
		puts opts
		exit
	end

end

begin
	optparse.parse!
	mandatory = [:config_file]
	missing = mandatory.select{ |param| options[param].nil? }
	if not missing.empty?
		puts "Missing options: #{missing.join(', ')}"
		puts
		puts optparse
		exit
	end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
	puts $!.to_s
	puts optparse
	exit
end


@config = YAML.load_file(options[:config_file])

# Exit if there's nothing on STDIN
exit(1) unless STDIN.fcntl(Fcntl::F_GETFL, 0) == 0

mail = Mail.new(STDIN.read())

@to = "@" + /^twitter\+([A-Za-z0-9_]+)@panic.com/.match(mail.to.first)[1] + " "

@sig = " -" + mail[:from].decoded.chars.first

reply_status_id = /^<(\d+)@.*>/.match(mail[:in_reply_to].decoded)[1]

body = /(.*)(On.*wrote:.*)/m.match(mail.body.decoded)[1].strip

# Strip out the email signature
@reply_text = /(.*)--/m.match(body)[1].strip

meta_count = "#{@to}#{@sig}".chars.count

msg = "#{@to} #{@reply_text} #{@sig}"

puts msg if options[:verbose]

char_count = msg.chars.count

if char_count > 140
	puts "Your message is too long: #{char_count} characters"
	exit(1)
end


@client = Twitter::Client.new(@config['oauth'])
@client.user(@config['username'])

@client.update(msg, {:in_reply_to_status_id => reply_status_id, :trim_user => 1}) unless options[:dryrun]