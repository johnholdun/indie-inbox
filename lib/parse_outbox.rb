class ParseOutbox
  # Maximum age, in hours, of a post that we'll still deliver
  MAX_AGE = 30

  def self.call
    activities =
      DB[:activities]
        .join(:actors, id: :actor_id)
        .where(delivered: false, managed: true)

    puts "activities:\n#{activities.map { |a| "  #{a[:json]}"}.join("\n")}"

    activities.each do |a|
      puts "#{a[:id]}…"
      json = Oj.load(a[:json])
      next unless json['to']
      next if (DateTime.now - DateTime.parse(json['published'])) * 24 > MAX_AGE

      account = DB[:actors].where(uri: a[:actor], managed: true).first
      account_json = FetchAccount.calll(account[:uri])

      # TODO: This is weird
      DB[:activities].where(id: a[:id]).update(delivered: true)

      inbox_urls =
        %w(to cc bcc).map { |k| json[k] }.flatten.compact

      if inbox_urls.include?(PUBLIC)
        # add followers by shared inbox or inbox
        inbox_urls +=
          DB[:follows]
            .where(object: account[:uri], accepted: true)
            .map do |follow|
              account = FetchAccount.call(follow[:actor])
              (account['endpoints'] || {})['sharedInbox'] || account['inbox']
            end
      end

      puts "inbox_urls:\n#{inbox_urls.uniq.sort.map { |d| "  #{d}" }.join("\n")}"

      inbox_urls.uniq.each do |inbox_url|
        next if inbox_url == PUBLIC
        delivery = Deliverer.call(account_json, inbox_url, json)
        puts "#{inbox_url}: #{delivery[:response] > 299}"
      end
    end
  end
end
