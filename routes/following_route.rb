class FollowingRoute < Route
  PAGE_SIZE = 50

  def call
    actor_id = request.params['actor_id']

    return not_found unless actor_id

    items = DB[:follows].where(actor_id: actor_id, accepted: true)
    page = request.params['page'].to_i

    total = items.count

    items =
      if page > 0
        items
        .limit(PAGE_SIZE + 1)
        .offset((page - 1) * PAGE_SIZE)
        .map(:actor)
      end

    headers['Content-Type'] = 'application/activity+json'

    finish_json \
      OrderedCollectionSerializer.call \
        uri: "/actors/#{actor_id}/following",
        total: total,
        items: items,
        page: page,
        page_size: PAGE_SIZE
  end
end
