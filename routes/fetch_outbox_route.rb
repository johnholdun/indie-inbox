class FetchOutboxRoute < Route
  def call
    actor_id = request.params['actor_id']
    actor = DB[:actors].where(id: actor_id, managed: true).first

    return not_found unless actor

    # Ensure we have the latest JSON for this user
    actor = FetchAccount.call(actor[:uri])

    # TODO: Rate limiting/caching on this request
    outbox = fetch(actor['outbox'])
    items = fetch(outbox['first'])

    # TODO: Fetch next page if there are activities we haven't seen? Maybe set a
    # limit?
    items['orderedItems'].each do |activity|
      id = activity.is_a?(String) ? activity : activity['id']
      existing = DB[:activities].where(uri: id).count > 0
      next if existing
      DB[:activities].insert(actor_id: actor_id, uri: id, json: activity.to_json)
    end

    return finish(nil, 202)
  end

  private

  def fetch(uri)
    Request
      .new(
        :get,
        uri,
        headers: { 'Accept' => 'application/activity+json, application/ld+json' }
      )
      .perform do |response|
        Oj.load(response.body_with_limit, mode: :strict) if response.code == 200
      end
  end
end
