#
# Copyright (C) 2014 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require 'nokogiri'

module Api
  module Html
    class Content
      def self.process_incoming(html)
        return html unless html.present?
        content = self.new(html)
        # shortcut html documents that definitely don't have anything we're interested in
        return html unless content.might_need_modification?

        content.modified_html
      end

      def self.rewrite_outgoing(html, url_helper)
        return html if html.blank?
        self.new(html).rewritten_html(url_helper)
      end

      attr_reader :html

      def initialize(html_string)
        @html = html_string
      end

      def might_need_modification?
        !!(html =~ %r{verifier=|['"]/files|instructure_inline_media_comment})
      end

      # Take incoming html from a user or similar and modify it for safe storage and display
      def modified_html
        parsed_html.search("*").each do |node|
          scrub_links!(node)
        end

        # translate audio and video tags generated by media comments back into anchor tags
        # try to add the relevant attributes to media comment anchor tags to retain MediaObject info
        parsed_html.css('audio.instructure_inline_media_comment, video.instructure_inline_media_comment, a.instructure_inline_media_comment').each do |node|
          tag = Html::MediaTag.new(node, parsed_html)
          next unless tag.has_media_comment?
          node.replace(tag.as_anchor_node)
        end

        return parsed_html.to_s
      end

      # a hash of allowed html attributes that represent urls, like { 'a' => ['href'], 'img' => ['src'] }
      UrlAttributes = CanvasSanitize::SANITIZE[:protocols].inject({}) { |h,(k,v)| h[k] = v.keys; h }

      # rewrite HTML being sent out to an API request to make sure
      # it has all necessary media elements and full URLs for later usage
      def rewritten_html(url_helper)
        # translate media comments into html5 video tags
        parsed_html.css('a.instructure_inline_media_comment').each do |anchor|
          tag = Html::MediaTag.new(anchor, parsed_html)
          next unless tag.has_media_comment?
          anchor.replace(tag.as_html5_node(url_helper))
        end

        UserContent.find_user_content(parsed_html) do |node, uc|
          apply_user_content_attributes(node, uc)
        end

        UserContent.find_equation_images(parsed_html) do |node|
          apply_mathml(node)
        end

        UrlAttributes.each do |tag, attributes|
          parsed_html.css(tag).each do |element|
            url_helper.rewrite_api_urls(element, attributes)
          end
        end
        parsed_html.to_s
      end


      private

      APPLICABLE_ATTRS = %w{href src}

      def scrub_links!(node)
        APPLICABLE_ATTRS.each do |attr|
          if link = node[attr]
            node[attr] = corrected_link(link)
          end
        end
      end

      def corrected_link(link)
        Html::Link.new(link).to_corrected_s
      end

      def parsed_html
        @_parsed_html ||= Nokogiri::HTML::DocumentFragment.parse(html)
      end

      def apply_user_content_attributes(node, user_content)
        node['class'] = "instructure_user_content #{node['class']}"
        node['data-uc_width'] = user_content.width
        node['data-uc_height'] = user_content.height
        node['data-uc_snippet'] = user_content.node_string
        node['data-uc_sig'] = user_content.node_hmac
      end

      def apply_mathml(node)
        self.class.apply_mathml(node)
      end

      def self.apply_mathml(node)
        mathml = UserContent.latex_to_mathml(node['alt'])
        return if mathml.blank?

        # replace alt attribute with mathml
        node.delete('alt')
        node['data-mathml'] = mathml
      end
    end
  end
end
