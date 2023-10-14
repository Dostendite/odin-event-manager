require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  phone_number = phone_number.scan(/\d/).join
  
  if phone_number.length > 10
    if phone_number[0] == '1'
      phone_number = phone_number[1..-1]
    else
      phone_number = 'Bad number'
    end
  end

  if phone_number.length < 10
    phone_number = 'Bad number'
    return phone_number
  end

  phone_number
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

def fetch_registration_hour(time_of_registration)
  time_format = "%m/%d/%y %H:%M"
  time_of_registration = Time.strptime(time_of_registration, time_format)
  hour_of_registration = time_of_registration.strftime("%R")
end

def fetch_registration_day(time_of_registration)
  time_format = "%m/%d/%y %H:%M"
  time_of_registration = Time.strptime(time_of_registration, time_format)
  day_of_registration = time_of_registration.strftime("%A")
end

hours_of_registration = []
days_of_registration = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  time_of_registration = row[:regdate]

  phone_number = clean_phone_number(row[:homephone])
  
  hour_of_registration = fetch_registration_hour(time_of_registration)
  hours_of_registration << hour_of_registration

  day_of_registration = fetch_registration_day(time_of_registration)
  days_of_registration << day_of_registration

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end

def print_most_common_weekday(days_of_registration)
  day_hash = {}

  days_of_registration.each do |day|
      day_hash[day] ? day_hash[day] += 1 : day_hash[day] = 1
  end

  most_common_day = day_hash.max_by { |k, v| v }[0]

  puts "Most common day of registration: #{most_common_day}"
end

def print_most_common_hour(hours_of_registration)
  exact_hours = []

  hours_of_registration.each do |hour|
    hour_and_minutes = hour.split(':')
    exact_hour = hour_and_minutes[0].to_i + hour_and_minutes[1].to_f / 60
    exact_hours << exact_hour.round(2)
  end

  mean_hour = exact_hours.sum / exact_hours.length
  mean_hour = mean_hour.to_i 

  if mean_hour < 12
    mean_hour = mean_hour.to_s + ' AM'
  else
    mean_hour = (mean_hour - 12).to_s + ' PM'
  end

  puts "Most common hour of registration: #{mean_hour}"
end

print_most_common_weekday(days_of_registration)
print_most_common_hour(hours_of_registration)