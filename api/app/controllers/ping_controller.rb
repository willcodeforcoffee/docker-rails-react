class PingController < ApplicationController
  def index
    render status: :ok, html: "OK"
  end
end
