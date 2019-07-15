require './lib/jsonld_helper'

class ParseInbox
  include JsonLdHelper

  def call
    puts 'Checking queue…'

    @payload = DB[:unverified_inbox].where(errors: nil).first
    raise 'no items' unless payload
    puts "row id: #{@payload[:id]}"

    process \
      payload[:body],
      signed_request_account

    DB[:unverified_inbox]
      .where(id: payload[:id])
      .delete
  rescue => error
    unless payload
      puts 'no items in queue'
      return
    end

    DB[:unverified_inbox]
      .where(id: payload[:id])
      .update(errors: error.to_json)
  ensure
    # Unless we hit the end of the queue, run this again
    self.class.call if payload
  end

  def self.call
    new.call
  end

  private

  attr_reader :payload

  def headers
    @headers ||= Oj.load(payload[:headers]) rescue {}
  end

  def process(body, account)
    json = Oj.load(body, mode: :strict)

    puts "#{json['id']}…"

    return unless supported_context?(json)

    if different_actor?(json, account)
      account =
        begin
          LinkedDataSignature.new(json).verify_account!
        rescue JSON::LD::JsonLdError => e
          puts \
            "Could not verify LD-Signature for #{value_or_id(json['actor'])}: #{e.message}"
          nil
        end

      return unless account
    end

    # If we've already seen this activity, ignore it
    return unless DB[:activities].where(uri: json['id']).count.zero?

    inboxes = %w(to cc bcc).flat_map { |m| json[m] }.compact

    recipients = []

    # TODO: What about unfollows and follow acceptances?
    case json['type']
    when 'Follow'
      actor_uri = json['object'].is_a?(String) ? json['object'] : json['object']['id']
      inboxes.push(actor_uri)
    when 'Undo'
      if json['object'].is_a?(Hash) && json['object']['type'] == 'Follow'
        actor_uri = json['object']['object'].is_a?(String) ? json['object']['object'] : json['object']['object']['id']
        inboxes.push(actor_uri)
      end
    when 'Accept'
      puts "uh accept #{json.to_json}"
    end

    if inboxes.include?(PUBLIC) || inboxes.include?(account['followers'])
      recipients +=
        DB[:follows]
          .join(:actors, id: :actor_id)
          .where(object_id: account['id'], managed: true, accepted: true)
          .map(:actor_id)
    end

    recipients +=
      DB[:actors]
        .where(managed: true, uri: inboxes)
        .map(:id)

    recipients.compact!
    recipients.uniq!

    if recipients.size.zero?
      puts 'No recipients'
      return
    end

    DB[:activities].insert \
      uri: json['id'],
      actor_id: DB[:actors].where(uri: account['id']).first[:id],
      json: json.to_json

    activity_id = DB[:activities].where(uri: json['id']).first[:id]

    recipients.each do |actor_id|
      DB[:inbox].insert(actor_id: actor_id, activity_id: activity_id)
    end

    items =
      case json['type']
      when 'Collection', 'CollectionPage'
        json['items']
      when 'OrderedCollection', 'OrderedCollectionPage'
        json['orderedItems']
      else
        [json]
      end

    recipients.each do |actor_id|
      items.reverse_each do |item|
        HandleIncomingItem.call(item, actor_id)
      end
    end
  rescue Oj::ParseError
    nil
  end

  def different_actor?(json, account)
    !json['actor'].to_s.size.zero? &&
    value_or_id(json['actor']) != account['id'] &&
    !json['signature'].to_s.size.zero?
  end

  def signed_request_account
    raise 'Request not signed' unless headers['Signature'].to_s.size > 0

    # begin
    #   time_sent = DateTime.httpdate(headers['Date'])
    # rescue ArgumentError
    #   raise 'Invalid date'
    # end

    # unless (Time.now.utc - time_sent).abs <= 30
    #   raise 'Expired date'
    # end

    signature_params = {}

    headers['Signature'].split(',').each do |part|
      parsed_parts = part.match(/([a-z]+)="([^"]+)"/i)
      next if parsed_parts.nil? || parsed_parts.size != 3
      signature_params[parsed_parts[1]] = parsed_parts[2]
    end

    unless signature_params['keyId'] && signature_params['signature']
      raise 'Incompatible request signature'
    end

    account = FetchAccount.call(signature_params['keyId'].sub(/#.+/, ''))

    unless account
      raise "Public key not found for key #{signature_params['keyId']}"
    end

    signed_headers = signature_params['headers'] || 'date'

    signed_string =
      signed_headers
      .split(' ')
      .map do |signed_header|
        if signed_header == Request::REQUEST_TARGET
          "#{Request::REQUEST_TARGET}: #{payload[:request_method].downcase} #{payload[:path]}"
        elsif signed_header == 'digest'
          puts "ummmmm digest #{payload[:body]}"
          "digest: SHA-256=#{Digest::SHA256.base64digest(payload[:body])}"
        else
          header =
            headers[signed_header.split(/-/).map(&:capitalize).join('-')]

          "#{signed_header}: #{header}"
        end
      end
      .join("\n")

    puts "asdfasdfsadf #{account['publicKey']['publicKeyPem'].inspect}"

    keypair =
      OpenSSL::PKey::RSA.new(account['publicKey']['publicKeyPem'])

    verified =
      keypair
        .public_key
        .verify \
          OpenSSL::Digest::SHA256.new,
          Base64.decode64(signature_params['signature']),
          signed_string

    return account if verified

    raise "Verification failed for #{account['id']}\n#{signed_string}"
  end
end
