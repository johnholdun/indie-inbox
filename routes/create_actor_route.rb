require 'securerandom'

class CreateActorRoute < Route
  def call
    auth_header = request['headers']['Authorization']

    unless CREATION_TOKEN.to_s.size > 0 && auth_header == "Bearer #{CREATION_TOKEN}"
      return 403
    end

    request_body = request.body.tap(&:rewind).read
    params = Oj.load(request_body) rescue CGI.parse(request_body)
    params ||= {}

    account = FetchAccount.call(params['uri'])

    return finish('Bad URI', 400) unless account

    DB[:actors].where(uri: params['uri']).update(private_key: params['private_key'], managed: true, auth_token: SecureRandom.hex(16))

    result = DB[:actors].where(uri: params['uri']).first.select { |k, _| %i(id auth_token).include?(k) }

    finish_json(result)
  end
end
