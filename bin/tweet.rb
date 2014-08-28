#!/usr/bin/env ruby

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
require 'active_support'

class String
  def display_length
    ActiveSupport::Multibyte::Chars.new(self).normalize(:c).length
  end
end

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
charset = "utf-8"

# Capture the twitter handle from the To: header
to_regex = /#{@config['mail']['mailbox']}\+([A-Za-z0-9_]+)@#{@config['mail']['delivery_configuration'][:domain]}/

to_line = mail.to.first
matches = to_regex.match(to_line)

if !matches
	$stderr.puts "The To: address (#{to_line}) isn't in the correct format. Make sure the account matches the setting in your config file: #{@config['mail']['mailbox']}"
	exit(1)
end

@to = "@" + matches[1]

# Form the signature from the first letter of the sender's name
first_char = mail[:from].decoded.chars.first
first_char = mail[:from].decoded.chars[1] if first_char == '"'

@sig = "—" + first_char

# Capture the status id of the tweet we're replying to
reply_status_regex = /^<(\d+)@#{@config['mail']['mailbox']}-#{@config['auth_token']}\.#{@config['mail']['delivery_configuration'][:domain]}>/

if !(mail[:in_reply_to].decoded =~ reply_status_regex)
	$stderr.puts "The In-Reply-To header isn't in the correct format"
	exit(1)
end

reply_status_id = reply_status_regex.match(mail[:in_reply_to].decoded)[1]

# We need to extract the text part from the message
decoded_body = ""

if (mail.multipart?)
	mail.parts.each do |part|
		if part.content_type =~ /plain/
			decoded_body = part.body.decoded
			charset = part.content_type_parameters["charset"]
		end
	end
else
	decoded_body = mail.body.decoded
	charset = mail.content_type_parameters["charset"]
end

# Apple Mail sends messages in windows-1252 when there are non-ascii characters present so we need to re-encode to UTF-8
matches = /(.*)On .* wrote:.*/m.match(decoded_body)

if !matches
  $stderr.puts "Couldn't parse the message body"
  exit(1)
end

untrusted_body = matches[1]

untrusted_body.chop!.chop! if untrusted_body[-2,2] == "> "
untrusted_body = untrusted_body.strip

ic = Iconv.new('UTF-8', charset)

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

char_count = msg.display_length

if char_count > 140
	$stderr.puts "Your message is too long: #{char_count} characters"
	$stderr.puts msg
	$stderr.puts "----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|"
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