require './lib/jsonld_helper'

class FetchAccount
  include JsonLdHelper

  FRESH_WINDOW = 60 * 60 * 24 * 3

  def initialize(uri)
    @uri = uri
  end

  def call
    account = fetch_saved
    return account if account && Time.now.to_i - account[:fetched_at].to_i <= FRESH_WINDOW
    account = fetch_by_id
    return unless account
    save_account(account)
    account
  end

  def self.call(*args)
    new(*args).call
  end

  private

  attr_reader :uri

  def managed?
    @managed
  end

  def fetch_saved
    result = DB[:actors].where(uri: uri).first
    @managed = result && result[:managed]
    LD_CONTEXT.merge(Oj.load(result[:json])) if result
  end

  def save_account(account)
    existing = DB[:actors].where(uri: uri)

    params =
      {
        fetched_at: Time.now,
        json: account.reject { |k, _| k == '@context' }.to_json
      }

    if existing.count > 0
      existing.update(params)
    else
      DB[:actors].insert(params.merge(uri: uri))
    end
  end

  def fetch_by_id
    json = fetch_resource(uri, false)

    return unless supported_context?(json)

    supported_type =
      ACTOR_TYPES.any? do |type|
        equals_or_includes?(json['type'], type)
      end

    return unless supported_type

    json
  end

  def fetch_resource(uri, id)
    unless id
      json = fetch_resource_without_id_validation(uri)
      return unless json
      return json if uri == json['id']
      uri = json['id']
    end

    json = fetch_resource_without_id_validation(uri)
    return unless json && json['id'] == uri
    json
  end

  def fetch_resource_without_id_validation(uri)
    Request
      .new(
        :get,
        uri,
        headers: { 'Accept' => 'application/activity+json, application/ld+json' }
      )
      .perform do |response|
        return Oj.load(response.body_with_limit, mode: :strict) if response.code == 200
      end
  rescue Oj::ParseError
    nil
  end
end
