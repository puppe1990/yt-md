# frozen_string_literal: true

unless ENV["SKIP_SIMPLECOV"]
  require "simplecov"
  SimpleCov.start do
    enable_coverage :branch
    skip "/test/"
    skip "/tools/"
    cover "lib/**/*.rb"
    command_name "Minitest"
  end
end

require "minitest/autorun"
require "faker"
require "json"
require "tmpdir"

require_relative "../lib/yt_md"
require_relative "yt_md/fake_innertube"

Faker::Config.locale = "en"

# Shared helpers for yt-md tests. Network stays out: HTTP is injected.
class YtMdTest < Minitest::Test
  def fake_video_id
    Faker::Alphanumeric.alphanumeric(number: 11)
  end

  def fake_title
    Faker::Book.title
  end

  def fake_channel
    Faker::Internet.username
  end

  def fake_browse_id
    "UC#{Faker::Alphanumeric.alphanumeric(number: 22)}"
  end

  def json3_body(cues)
    events = cues.map do |cue|
      {
        "tStartMs" => cue.fetch(:start_ms),
        "dDurationMs" => cue.fetch(:duration_ms, 1000),
        "segs" => Array(cue.fetch(:text)).map { |piece| { "utf8" => piece } }
      }
    end
    JSON.generate("wireMagic" => "pb3", "events" => events)
  end

  def timedtext_url_for(video_id, language: "en")
    "https://www.youtube.com/api/timedtext?v=#{video_id}&lang=#{language}&kind=asr"
  end

  def player_payload_json(video_id:, title: fake_title, channel: fake_channel, timedtext_url: nil,
                          tracks: nil, status: "OK", reason: nil, length: "3135")
    tracks ||= [
      { "languageCode" => "en", "kind" => "asr", "baseUrl" => timedtext_url }
    ]
    JSON.generate(
      "playabilityStatus" => { "status" => status, "reason" => reason },
      "videoDetails" => {
        "videoId" => video_id,
        "title" => title,
        "author" => channel,
        "lengthSeconds" => length
      },
      "captions" => {
        "playerCaptionsTracklistRenderer" => { "captionTracks" => tracks }
      }
    )
  end

  def videos_tab_lockup(video_id, title)
    {
      "richItemRenderer" => {
        "content" => {
          "lockupViewModel" => {
            "contentId" => video_id,
            "contentType" => "LOCKUP_CONTENT_TYPE_VIDEO",
            "metadata" => {
              "lockupMetadataViewModel" => { "title" => { "content" => title } }
            }
          }
        }
      }
    }
  end

  def videos_tab_continuation(token)
    {
      "continuationItemRenderer" => {
        "continuationEndpoint" => {
          "continuationCommand" => { "token" => token }
        }
      }
    }
  end

  def videos_tab_page(items)
    JSON.generate(
      "contents" => {
        "twoColumnBrowseResultsRenderer" => {
          "tabs" => [
            {
              "tabRenderer" => {
                "selected" => true,
                "title" => "Videos",
                "content" => { "richGridRenderer" => { "contents" => items } }
              }
            }
          ]
        }
      }
    )
  end

  def videos_tab_continuation_page(items)
    JSON.generate(
      "onResponseReceivedActions" => [
        { "appendContinuationItemsAction" => { "continuationItems" => items } }
      ]
    )
  end

  def resolve_url_json(browse_id)
    JSON.generate("endpoint" => { "browseEndpoint" => { "browseId" => browse_id } })
  end

  def comments_watch_json(title: fake_title, channel: fake_channel,
                          count: "9", sorts: %w[Top Newest], tokens: nil, disabled: false, collab: false)
    tokens ||= sorts.map { |sort| "#{sort.downcase}-token-#{Faker::Alphanumeric.alphanumeric(number: 8)}" }
    panels = []
    unless disabled
      panels << {
        "engagementPanelSectionListRenderer" => {
          "panelIdentifier" => YtMd::CommentPanel::PANEL_ID,
          "header" => {
            "engagementPanelTitleHeaderRenderer" => {
              "title" => { "runs" => [{ "text" => "Comentários" }] },
              "contextualInfo" => { "runs" => [{ "text" => count }] },
              "menu" => {
                "sortFilterSubMenuRenderer" => {
                  "subMenuItems" => sorts.each_with_index.map do |sort, index|
                    {
                      "title" => sort,
                      "selected" => index.zero?,
                      "serviceEndpoint" => { "continuationCommand" => { "token" => tokens[index] } }
                    }
                  end
                }
              }
            }
          }
        }
      }
    end
    JSON.generate(
      "contents" => {
        "twoColumnWatchNextResults" => {
          "results" => {
            "results" => {
              "contents" => [
                {
                  "videoPrimaryInfoRenderer" => { "title" => { "runs" => [{ "text" => title }] } }
                },
                {
                  "videoSecondaryInfoRenderer" => {
                    "owner" => { "videoOwnerRenderer" => owner_view(channel, collab) }
                  }
                }
              ]
            }
          }
        }
      },
      "engagementPanels" => panels
    )
  end

  # Collab videos ship `attributedTitle.content` and no `title`.
  def owner_view(channel, collab)
    return { "attributedTitle" => { "content" => channel } } if collab

    { "title" => { "runs" => [{ "text" => channel }] } }
  end

  # One continuation page: thread/reply items plus their frameworkUpdates
  # entities. Each row is { author:, text:, likes:, published:, replies: n }.
  def comments_page_json(rows, next_token: nil, reply_token: nil, level: 0, reply_rows: nil, more_token: nil)
    items = []
    mutations = []
    rows.each do |row|
      key = "entity-#{Faker::Alphanumeric.alphanumeric(number: 12)}"
      comment_id = Faker::Alphanumeric.alphanumeric(number: 24)
      mutations << comment_entity(key, comment_id, row, level: level)
      view = { "commentKey" => key, "commentId" => comment_id }
      view["pinnedText"] = row[:pinned] if row[:pinned]
      thread = { "commentViewModel" => { "commentViewModel" => view } }
      thread["replies"] = replies_renderer(reply_token, row[:replies]) if threaded_replies?(level, reply_token, row)
      items << { "commentThreadRenderer" => thread }
    end
    fill_reply_rows(items, mutations, reply_rows) if reply_rows
    items << comments_continuation(next_token) if next_token
    items << show_more_button(more_token) if more_token
    JSON.generate(
      "onResponseReceivedEndpoints" => [
        { "reloadContinuationItemsCommand" => { "continuationItems" => items } }
      ],
      "frameworkUpdates" => { "entityBatchUpdate" => { "mutations" => mutations } }
    )
  end

  def comment_entity(key, comment_id, row, level:)
    {
      "entityKey" => key,
      "payload" => {
        "commentEntityPayload" => {
          "properties" => {
            "commentId" => comment_id,
            "content" => { "content" => row.fetch(:text) },
            "publishedTime" => row[:published] || "há 1 dia",
            "replyLevel" => level
          },
          "author" => {
            "displayName" => row.fetch(:author),
            "isCreator" => row[:creator] == true,
            "channelCommand" => {
              "innertubeCommand" => {
                "browseEndpoint" => { "canonicalBaseUrl" => "/#{row.fetch(:author)}" }
              }
            }
          },
          "toolbar" => {
            "likeCountNotliked" => row[:likes] || " ",
            "replyCount" => row[:replies].to_s
          }
        }
      }
    }
  end

  def replies_renderer(reply_token, reply_count)
    {
      "commentRepliesRenderer" => {
        "contents" => [
          {
            "continuationItemRenderer" => {
              "continuationEndpoint" => {
                "continuationCommand" => { "token" => reply_token }
              }
            }
          }
        ],
        "viewReplies" => { "buttonRenderer" => { "text" => { "runs" => [{ "text" => "#{reply_count} replies" }] } } }
      }
    }
  end

  def comments_continuation(token)
    videos_tab_continuation(token)
  end

  # Reply pages end with "Mostrar mais respostas": the token lives on the
  # button's command, not on continuationEndpoint.
  def show_more_button(token)
    {
      "continuationItemRenderer" => {
        "button" => {
          "buttonRenderer" => {
            "text" => { "runs" => [{ "text" => "Mostrar mais respostas" }] },
            "command" => { "continuationCommand" => { "token" => token } }
          }
        }
      }
    }
  end

  def threaded_replies?(level, reply_token, row)
    level.zero? && !reply_token.nil? && row[:replies].to_i.positive?
  end

  def fill_reply_rows(items, mutations, reply_rows)
    thread = items.first["commentThreadRenderer"]
    thread["replies"]["commentRepliesRenderer"]["contents"] = reply_rows.map do |row|
      key = "reply-#{Faker::Alphanumeric.alphanumeric(number: 12)}"
      comment_id = Faker::Alphanumeric.alphanumeric(number: 24)
      mutations << comment_entity(key, comment_id, row, level: 1)
      { "commentViewModel" => { "commentViewModel" => { "commentKey" => key, "commentId" => comment_id } } }
    end
  end
end
