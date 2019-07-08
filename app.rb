require 'sinatra/base'

class IndieInbox < Sinatra::Application
  @my_routes =
    [
      [:post, '/actors/?', CreateActorRoute],
      [:get, '/actors/:actor_id/?', RedirectActorRoute],
      [:put, '/actors/:actor_id/?', FetchOutboxRoute],
      [:get, '/actors/:actor_id/inbox/?', ReadInboxRoute],
      [:post, '/actors/:actor_id/inbox/?', InboxRoute],
      [:post, '/inbox/?', InboxRoute],
      [:get, '/actors/:actor_id/followers/?', FollowersRoute],
      [:get, '/actors/:actor_id/following/?', FollowingRoute]
    ]

  @my_routes.each do |meth, path, klass|
    send(meth, path) do
      formatted_request =
        request.tap do |req|
          req.params.merge!(params)
          headers =
            req
            .env
            .keys
            .select { |k| k.start_with?('HTTP_') }
            .each_with_object({}) do |key, hash|
              header_name =
                key
                  .downcase
                  .sub(/^http_./) { |foo| foo[-1].upcase }
                  .gsub(/_./) { |foo| "-#{foo[1].upcase}" }

              hash[header_name] = req.env[key]
            end

          headers['Content-Type'] = req.env['CONTENT_TYPE']

          req['headers'] = headers
        end

      klass.call(formatted_request)
    end
  end
end
