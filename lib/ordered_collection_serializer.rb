class OrderedCollectionSerializer < Service
  attribute :uri
  attribute :total
  attribute :items
  attribute :page
  attribute :page_size

  def call
    if page.to_i > 0
      LD_CONTEXT.merge \
        id: "#{uri}?page=#{page}",
        type: 'OrderedCollectionPage',
        totalItems: total,
        next: ("#{uri}?page=#{page + 1}" if total > page * page_size),
        prev: ("#{uri}?page=#{page - 1}" if page > 1),
        partOf: uri,
        items: items
    else
      LD_CONTEXT.merge \
        id: uri,
        type: 'OrderedCollection',
        totalItems: total,
        first: "#{uri}?page=1"
    end
  end
end
