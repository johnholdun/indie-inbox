class RedirectActorRoute < Route
  def call
    result = DB[:actors].where(id: request.params['actor_id'], managed: true).first

    return finish('Invalid id', 404) unless result

    [301, { 'Location' => result[:uri] }, []]
  end
end
