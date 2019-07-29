class FetchOutboxRoute < Route
  def call
    @actor_id = request.params['actor_id']
    actor = DB[:actors].where(id: actor_id, managed: true).first

    return not_found unless actor

    # Ensure we have the latest JSON for this user
    actor = FetchAccount.call(actor[:uri])

    # TODO: Rate limiting/caching on this request
    outbox = fetch(actor['outbox'])
    save_outbox_page(outbox['first'])

    return finish(nil, 202)
  end

  private

  attr_reader :actor_id

  def save_outbox_page(url)
    page = fetch(url)

    found = 0

    page['orderedItems'].each do |activity|
      id = activity.is_a?(String) ? activity : activity['id']
      existing = DB[:activities].where(uri: id).count > 0
      next if existing
      found += 1
      DB[:activities].insert(actor_id: actor_id, uri: id, json: activity.to_json)
    end

    return if found.zero?
    return unless page['next'] && !page['next'].size.zero?
    save_outbox_page(page['next'])
  end

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
