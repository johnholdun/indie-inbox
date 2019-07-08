require 'bundler'

Bundler.require
Dotenv.load

Dir.glob('./lib/*.rb').each { |f| require(f) }
Dir.glob('./routes/*.rb').each { |f| require(f) }

CREATION_TOKEN = ENV['CREATION_TOKEN'].freeze

HOST = ENV['HOST'].freeze

BASE_URL = "https://#{HOST}"

LD_CONTEXT = {
  '@context': [
    'https://www.w3.org/ns/activitystreams',
    'https://w3id.org/security/v1'
  ]
}.freeze

PUBLIC = 'https://www.w3.org/ns/activitystreams#Public'.freeze

ACTOR_TYPES =
  %w(
    Application
    Group
    Organization
    Person
    Service
  ).freeze

DB = Sequel.connect(ENV['DATABASE_URL'])

Schema.load!

Oj.default_options = { mode: :compat, time_format: :ruby, use_to_json: true }
