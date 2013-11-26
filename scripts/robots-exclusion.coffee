# Description:
#   robots.txt generator
#
# Configuration
#   HUBOT_ROBOTS_EXCLUSION - comma separated exclusion list
#
# URLS:
#   /robots.txt

DISALLOW_ALL = '/'

generate_robots_txt = (disallow) ->
  """
  User-agent: *
  #{disallow.map((v) -> 'Disallow: ' + v).join("\n")}
  """

disallow_list = -> (process.HUBOT_ROBOTS_EXCLUSION || DISALLOW_ALL).split ','

module.exports = (robot) ->
  robot.router.get "/robots.txt", (req, res) ->
    res.type 'text/plain'
    res.send generate_robots_txt disallow_list()
