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
require 'iconv'

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

# Capture the twitter handle from the To: header
to_regex = /^#{@config['mail']['mailbox']}\+([A-Za-z0-9_]+)@#{@config['mail']['delivery_configuration'][:domain]}/

if !(mail.to.first =~ to_regex)
	$stderr.puts "The To: address isn't in the correct format"
	exit(1)
end

@to = "@" + to_regex.match(mail.to.first)[1] + " "

# Form the signature from the first letter of the sender's name
@sig = " —" + mail[:from].decoded.chars.first

# Capture the status id of the tweet we're replying to
reply_status_regex = /^<(\d+)@#{@config['mail']['mailbox']}-#{@config['auth_token']}\.#{@config['mail']['delivery_configuration'][:domain]}>/

if !(mail[:in_reply_to].decoded =~ reply_status_regex)
	$stderr.puts "The In-Reply-To header isn't in the correct format"
	exit(1)
end

reply_status_id = reply_status_regex.match(mail[:in_reply_to].decoded)[1]

# Apple Mail sends messages in windows-1252 when there are non-ascii characters present
untrusted_body = /(.*)(On.*wrote:.*)/m.match(mail.body.decoded)[1].strip
ic = Iconv.new('UTF-8', 'WINDOWS-1252')
body = ic.iconv(untrusted_body + ' ')[0..-2]

# Strip out the signature
signature_regex = /(.*)--/m
if signature_regex.match(body)
	@reply_text = signature_regex.match(body)[1].strip
else
	@reply_text = body
end

msg = "#{@to} #{@reply_text} #{@sig}"

puts msg if options[:verbose]

char_count = msg.chars.count

if char_count > 140
	$stderr.puts "Your message is too long: #{char_count} characters"
	exit(1)
end

# Update the Twitter status
@client = Twitter::Client.new(@config['oauth'])
@client.user(@config['username'])

begin
	@client.update(msg, {:in_reply_to_status_id => reply_status_id, :trim_user => 1}) unless options[:dryrun]
rescue
	$stderr.print "Unable to post twitter update: " + $!
end