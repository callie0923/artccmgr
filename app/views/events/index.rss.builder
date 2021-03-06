# encoding: UTF-8
# frozen_string_literal: true

xml.instruct! :xml, version: '1.0'
xml.rss version: '2.0' do
  xml.channel do
    xml.title "#{Settings.artcc_name} Events"
    xml.author Settings.artcc_name
    xml.description 'Events Calendar'
    xml.lastBuildDate Time.now.utc
    xml.link root_url
    xml.language 'en'

    @events.each do |event|
      xml.item do
        xml.title event.name
        xml.author 'ARTCC Manager Events'
        xml.pubDate event.start_time.to_s(:rfc822)
        xml.link event_url(event)
        xml.guid event.id
        xml.description event.description
      end
    end
  end
end
