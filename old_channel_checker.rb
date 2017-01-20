#!/usr/bin/env ruby

require 'json'
require 'date'
require 'typhoeus'

# List Slack channels
class OldChannelChecker
  def initialize(num_days)
    @num_days = num_days
    @token = ENV['SLACK_TOKEN']
    @list_url = 'https://slack.com/api/channels.list'
    @old_channels = []
  end

  def list
    url = @list_url
    response = Typhoeus.post(url, body: { token: @token })
    read_response(response)
    puts "#{@old_channels.count} channels"
  end

  def do_post(url, payload)
    response = Typhoeus.post(url, body: payload)
    [response.response_code, response.body]
  end

  def read_response(response)
    if response.response_code == 200
      channels = JSON.parse(response.body)['channels']
      show_channels(channels)
    else
      puts "Error: #{response.response_code}"
      puts response.body
      exit
    end
  end

  def show_channels(channels)
    channels.each do |c|
      next unless c['num_members'] > 0
      channel_name = c['name']
      channel_id   = c['id']
      check_last_post(channel_name, channel_id)
    end
  end

  def check_last_post(channel_name, channel_id)
    payload = {}
    payload['token']   = @token
    payload['channel'] = channel_id
    payload['count']   = 1
    _, body = do_post('https://slack.com/api/channels.history', payload)
    show_date_diff(channel_name, body)
  end

  def show_date_diff(channel_name, body)
    json = JSON.parse(body)
    ts = json['messages'][0]['ts']
    date = Time.at(ts.to_i)
    diff = date_diff(date)

    return unless diff > @num_days.to_i

    puts "#{channel_name}: #{date.to_s[0..10]}: #{diff} days"
    @old_channels << channel_name
  end

  def date_diff(ts)
    now = Time.now
    (now.to_i - ts.to_i) / 86_400
  end
end

num_days = ARGV[0]
OldChannelChecker.new(num_days).list
