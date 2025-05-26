# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'io/console'
require 'json'

# banner created with https://patorjk.com/software/taag/ font 'Big'
banner = <<TT
  _______        _                #######
 |__   __|      | |             ##   #   ##
    | | ___  ___| |_ __ _ _   ##___  #     ##
    | |/ _ \\/ __| __/ _` | | | / __| #  #    #
    | |  __/\\__ \\ || (_| | |_| \\__ \\ # #      #
    |_|\\___||___/\\__\\__,_|\\__,_|___/ ##       #
    | | (_)                 #                 #
    | |_ _ _ __ ___   ___    #               #
    |  _| | '_ ` _ \\ / _ \\    ##           ##
    | |_| | | | | | |  __/      ##       ##
     \\__|_|_| |_| |_|\\___|        #######

      D A T A  D E S T R O Y E R

TT

URI_AUTH = 'https://api.testaustime.fi/auth/login'
URI_SEC  = 'https://api.testaustime.fi/auth/securedaccess'
URI_DATA = 'https://api.testaustime.fi/users/@me/activity/data'
URI_DEL  = 'https://api.testaustime.fi/activity/delete'

def ask_credentials
  print 'Provide your username: '
  user = gets.chomp
  print 'and password: '
  passw = $stdin.noecho(&:gets).chomp
  puts
  @creds = JSON.dump({ 'username' => user, 'password' => passw })
  puts
end

def make_http_request(url, http_req_type, headers = {}, body = nil)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP.const_get(http_req_type).new(uri)
  headers.each { |key, value| request[key] = value }
  request.body = body if body
  @response = http.request(request)
  if @response.code != '200'
    abort('something went wrong')
  end
end

def get_token(type)
  source = @response.body
  match = source.match(/[a-zA-Z0-9]{32}/)
  token = match[0].to_s
  puts "Your #{type} token: #{token[0..2]}#{'*' * (token.length - 6)}#{token[-3..]}"
  return token
end

def response_data
  source = @response.body.force_encoding('UTF-8').downcase # remove .downcase for case sensitive search 1/2
  lines = source.scan(/\{.*?\}/)
  @all_lines = []
  lines.each do |line|
    @all_lines << line
  end
end

def selected_lines(action)
  print "What do you want to #{action}? "
  words = gets.chomp.downcase.split(',').map(&:strip) # remove .downcase for case sensitive search 2/2
  @selected_lines = @all_lines.public_send(action == 'save' ? :reject : :select) do |line|
    words.any? { |word| line.include?(word) } # .any? is OR search, replace with .all? for AND search
  end
  selected_action(action)
end

def selected_action(action)
  case action
  when 'view'
    print_lines(@selected_lines)
  when 'delete', 'save'
    confirm_and_delete(@selected_lines)
  end
end

def confirm_and_delete(chosen)
  puts "Deletes #{chosen.length} data records"
  if confirm_deletion
    delete_request(chosen)
  else
    puts 'Deletion cancelled'
  end
end

def print_lines(lines)
  puts "\n=== DATA LINES (#{lines.length}) ==="
  lines.each_with_index do |line, i|
    puts "#{i + 1}. #{line}"
  end
end

def timer
  59 - ((Time.now.to_i - @req_time.to_i) / 60)
end

def print_menu
  puts
  puts "You have #{@all_lines.length} data records"
  puts
  puts "    Options
      1 - Delete all
      2 - Delete selected
      3 - Save selected
      4 - Renew security token #{timer <= 0 ? '(expired)' : "(#{timer} min remaining)"}
      5 - [DEBUG] See all
      6 - [DEBUG] See selected
      7 - Exit"
  puts
  print 'Please select: '
  @select = gets.chomp.to_i
end

def menu_selection
  case @select
  when 1
    confirm_and_delete(@all_lines)
  when 2
    selected_lines('delete')
  when 3
    selected_lines('save')
  when 4
    make_http_request(URI_SEC, 'Post', @header_json, @creds)
    @sec_token = get_token('security')
    @req_time = Time.now
  when 5
    print_lines(@all_lines)
  when 6
    selected_lines('view')
  when 7
    :exit
  else
    puts 'Not a valid option.'
  end
end

def extract_ids(lines)
  regex = /(?<="id":)(\d*)(?=,)/
  lines.flat_map { |line| line.scan(regex) }
end

def delete_request(lines_to_delete)
  id_list = extract_ids(lines_to_delete)
  id_list.each do |id|
    header_del = { 'Authorization' => "Bearer #{@sec_token}" }
    body_del = id[0]
    make_http_request(URI_DEL, 'Delete', header_del, body_del)
    id_list.length > 20 ? sleep(2.5) : sleep(1.5)
    if @response.code == '200'
      puts 'Data record deleted.'
    else
      puts 'Deletion failed.'
    end
  end
end

def confirm_deletion
  print 'Delete data? (y/n): '
  response = gets.chomp.downcase
  case response
  when 'y'
    return true
  when 'n'
    return false
  else
    puts "Invalid input. Please enter 'y' or 'n'."
  end
end

puts banner

ask_credentials

@header_json = { 'Content-Type' => 'application/json' }
make_http_request(URI_AUTH, 'Post', @header_json, @creds)
auth_token = get_token('authentication')

make_http_request(URI_SEC, 'Post', @header_json, @creds)
@sec_token = get_token('security')

@req_time = Time.now

header_data = { 'Authorization' => "Bearer #{auth_token}" }

loop do
  make_http_request(URI_DATA, 'Get', header_data)

  response_data

  print_menu

  break if menu_selection == :exit
end
