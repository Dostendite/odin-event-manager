require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(phone_number)
  # 414-520-5000
  # (941)979-2000
  # 778.232.7000
  # 14018685000
  # 9.82E+00

  # 1. get only the digits
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
  hour_of_registration = time_of_registration.strftime("%k:%M")
end

def fetch_registration_day(time_of_registration)
  time_format = "%m/%d/%y %H:%M"
  time_of_registration = Time.strptime(time_of_registration, time_format)
  day_of_registration = time_of_registration.strftime("%A")
end

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  # get hour of registration
  time_of_registration = row[:regdate]

  phone_number = clean_phone_number(row[:homephone])
  
  # then get most common hour of registration
  hour_of_registration = fetch_registration_hour(time_of_registration)

  # then get most common week of registration
  day_of_registration = fetch_registration_day(time_of_registration)

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)
end
