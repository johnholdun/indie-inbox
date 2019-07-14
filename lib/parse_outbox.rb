class ParseOutbox
  # Maximum age, in hours, of a post that we'll still deliver
  MAX_AGE = 30

  def self.call
    activities =
      DB[:activities]
        .select(
          Sequel[:activities][:id].as(:id),
          Sequel[:activities][:json].as(:json),
          Sequel[:actors][:uri].as(:actor_uri)
        )
        .join(:actors, id: :actor_id)
        .where(delivered: false, managed: true)

    puts "activities:\n#{activities.map { |a| "  #{a[:json]}"}.join("\n")}"

    activities.each do |a|
      # TODO: This is weird
      DB[:activities].where(id: a[:id]).update(delivered: true)

      json = Oj.load(a[:json])

      if json.is_a?(String)
        puts "id: #{json}…"
        puts 'this one needs dereferencing'
        json = fetch(json)
      else
        puts "id: #{json['id']}…"
      end

      unless json['to']
        puts "no `to`!"
        next
      end

      if (DateTime.now - DateTime.parse(json['published'])) * 24 > MAX_AGE
        puts "too old (#{json['published']})!"
        next
      end

      inbox_urls = %w(to cc bcc).map { |k| json[k] }.flatten.compact

      if inbox_urls.include?(PUBLIC)
        # add followers by shared inbox or inbox
        inbox_urls +=
          DB[:follows]
            .where(object: a[:actor_uri], accepted: true)
            .map do |follow|
              account = FetchAccount.call(follow[:actor])
              (account['endpoints'] || {})['sharedInbox'] || account['inbox']
            end
      end

      puts "inbox_urls:\n#{inbox_urls.uniq.sort.map { |d| "  #{d}" }.join("\n")}"

      account_json = FetchAccount.call(a[:actor_uri])

      inbox_urls.uniq.each do |inbox_url|
        next if inbox_url == PUBLIC
        delivery = Deliverer.call(account_json, inbox_url, json)
        puts "#{inbox_url}: #{delivery[:response] > 299}"
      end
    end
  end

  # TODO: This is copied in FetchOutboxRoute
  def self.fetch(uri)
    Request
      .new(
        :get,
        uri,
        headers: { 'Accept' => 'application/activity+json, application/ld+json' }
      )
      .perform do |response|
        return Oj.load(response, mode: :strict) if response.code == 200
      end
  end
end
