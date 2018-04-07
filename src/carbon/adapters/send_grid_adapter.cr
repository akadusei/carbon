require "http"
require "json"

class Carbon::SendGridAdapter < Carbon::Adapter
  private getter api_key : String
  private getter? sandbox : Bool

  def initialize(@api_key, @sandbox = false)
  end

  def deliver_now(email : Carbon::Email)
    Carbon::SendGridAdapter::Email.new(email, api_key, sandbox?).deliver
  end

  class Email
    BASE_URI       = "api.sendgrid.com"
    MAIL_SEND_PATH = "/v3/mail/send"
    private getter email, api_key
    private getter? sandbox : Bool

    def initialize(@email : Carbon::Email, @api_key : String, @sandbox = false)
    end

    def deliver
      client.post(MAIL_SEND_PATH, body: params.to_json).tap do |response|
        unless response.success?
          raise JSON.parse(response.body).inspect
        end
      end
    end

    # :nodoc:
    # Used only for testing
    def params
      {
        personalizations: [personalizations],
        subject:          email.subject,
        from:             from,
        content:          content,
        mail_settings:    {sandbox_mode: {enable: sandbox?}},
      }
    end

    private def personalizations
      {
        to:  to_send_grid_address(email.to),
        cc:  to_send_grid_address(email.cc),
        bcc: to_send_grid_address(email.bcc),
      }.to_h.reject do |key, value|
        value.empty?
      end
    end

    private def to_send_grid_address(addresses : Array(Carbon::Address))
      addresses.map do |carbon_address|
        {
          name:  carbon_address.name,
          email: carbon_address.address,
        }
      end
    end

    private def from
      {
        email: email.from.address,
        name:  email.from.name,
      }.to_h.reject do |key, value|
        value.nil?
      end
    end

    private def content
      [
        text_content,
        html_content,
      ].compact
    end

    private def text_content
      body = email.text_body
      if body && !body.empty?
        {
          type:  "text/plain",
          value: body,
        }
      end
    end

    private def html_content
      body = email.html_body
      if body && !body.empty?
        {
          type:  "text/html",
          value: body,
        }
      end
    end

    @_client : HTTP::Client?

    private def client : HTTP::Client
      @_client ||= HTTP::Client.new(BASE_URI, port: 443, tls: true).tap do |client|
        client.before_request do |request|
          request.headers["Authorization"] = "Bearer #{api_key}"
          request.headers["Content-Type"] = "application/json"
        end
      end
    end
  end
end