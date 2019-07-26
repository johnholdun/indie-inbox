class ReadInboxRoute < Route
  LIMIT = 20

  def call
    @account =
      DB[:actors].where(id: request.params['actor_id']).first

    return not_found unless @account

    unless request['headers']['Authorization'] == "Bearer #{@account[:auth_token]}"
      return finish('Not authorized', 401)
    end

    @actor_id = @account[:id]

    @account = Oj.load(@account[:json])

    headers['Content-Type'] = 'application/activity+json'

    if request.params['cursor']
      activities = fetch_activities(request.params)

      next_cursor =
        if activities.size > 0
          if activities.first[:cursor] < max_cursor
            activities.first[:cursor]
          end
        elsif request.params['cursor'] =~ /^-/
          request.params['cursor'].to_i.abs
        end

      prev_cursor =
        if activities.size > 0
          if activities.last[:cursor] > min_cursor
            "-#{activities.last[:cursor]}"
          end
        elsif request.params['cursor'] !~ /^-/
          "-#{request.params['cursor'].to_i}"
        end

      finish_json \
        LD_CONTEXT.merge \
          id: account_inbox_url(cursor: request.params['cursor']),
          type: 'OrderedCollectionPage',
          totalItems: all_activities.count,
          next: (account_inbox_url(cursor: next_cursor) if next_cursor),
          prev: (account_inbox_url(cursor: prev_cursor) if prev_cursor),
          partOf: account_inbox_url,
          orderedItems: activities.map { |a| Oj.load(a[:json]) }
    else
      finish_json \
        LD_CONTEXT.merge \
          id: account_inbox_url,
          type: 'CollectionPage',
          totalItems: all_activities.count,
          first: account_inbox_url(cursor: '0'),
          last: account_inbox_url(cursor: '-0')
    end
  end

  private

  def account_inbox_url(params = {})
    path = @account['inbox']
    params.size > 0 ? "#{path}?#{to_query(params)}" : path
  end

  def to_query(params)
    params.map { |k, v| "#{k}=#{v}" }.join('&')
  end

  def all_activities
    @all_activities ||=
      DB[:inbox]
        .select(
          Sequel[:inbox][:actor_id].as(:actor_id),
          Sequel[:inbox][:cursor].as(:cursor),
          Sequel[:activities][:json].as(:json)
        )
        .join(:activities, id: :activity_id)
        .where(Sequel[:inbox][:actor_id] => @actor_id)
  end

  def min_cursor
    @min_cursor ||=
      DB[:inbox].order(:cursor).where(actor_id: @actor_id).first[:cursor]
  end

  def max_cursor
    @max_cursor ||=
      DB[:inbox].reverse(:cursor).where(actor_id: @actor_id).first[:cursor]
  end

  def fetch_activities(params)
    query = all_activities.limit(LIMIT)

    cursor = params['cursor']

    if cursor == '0'
      query = query.order(:cursor)
    elsif cursor == '-0'
      query = query.reverse(:cursor)
    elsif cursor =~ /^-/
      query = query.reverse(:cursor).where { cursor < cursor.to_i.abs }
    else
      query = query.order(:cursor).where { cursor > cursor.to_i }
    end

    result = query.to_a
    result.reverse! if cursor =~ /^-/
    result
  end
end
