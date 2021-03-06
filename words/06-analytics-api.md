Some portals expose an analytics page.
It turns out its data come from a reasonably straightforward JSON API.
Let's see what we can get from that.

## AJAX requests on the analytics page (Don't put this in the blog post.)
[This page](https://data.oregon.gov/analytics) makes a bunch
of AJAX requests, including

    https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&method=series&slice=DAILY&_=1376438538377
    https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&_=1376438538384
    https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&method=top&top=DATASETS&_=1376438538392
    https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&method=top&top=REFERRERS&_=1376438538397
    https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&method=top&top=SEARCHES&_=1376438538402
    https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&method=top&top=EMBEDS&_=1376438538409

There's also a mechanism for batch requests. Some of the above methods
return 4x4 ids, and the page seems to use the batch endpoint to get the
metadata for multiple datasets in one request.

    https://data.oregon.gov/api/batches

The `site_metrics.json` endpoint is the interesting one,
so I figured out how it works. 

## Site metrics endpoint

    GET /api/site_metrics.json

You access this endpoint by making a typical GET request; you don't need
any special cookie, header, or API key. Two query arguments are required

* `start`
* `end`

These are both dates, represented as milliseconds since January 1, 1970.
(Something like <script>document.write((new Date()).getTime())</script><noscript>1376439688459</noscript>)
These arguments define the range within which the analytics will be aggregated.

This endpoint exposes three methods.

* `top`
* `series`
* no method.

### Site-wide statistics (no method)

    GET /api/site_metrics.json

If you specify no method argument, you'll get some statistics
about the entire portal, such as the total number of datasets
created since the beginning of time (`datasets-created-total`),
the number of datasets created within the date range specified
by `start` and `end` (`datasets-created`), and the number of
rows of data that were accessed via the API within the date
range (`rows-accessed-api`).

    curl https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999
    {
      "datasets-created-total" : 5623,
      "datasets-deleted-total" : 4801,
      "datasets-created-blobby-total" : 113,
      "datasets-deleted-blobby-total" : 4,
      "datasets-created-href-total" : 13,
      "datasets-deleted-href-total" : 10,
      "rows-created-total" : 40757082,
      "rows-deleted-total" : 25546425,
      "page-views-total" : 2599228,
      "embeds-total" : 489504,
      "embeds" : 12094,
      "maps-created" : 99,
      "bytes-out" : 112213178897,
      "page-views" : 74530,
      "rows-loaded-api" : 20272,
      "rows-accessed-website" : 59636,
      "rows-loaded-download" : 8771634,
      "rows-accessed-api" : 611,
      "rows-loaded-website" : 778954,
      "rows-deleted" : 628998,
      "rows-accessed-rss" : 610,
      "maps-deleted" : 99,
      "filters-created" : 4995,
      "rows-loaded-widget" : 1347648,
      "rows-accessed-widget" : 67687,
      "geocoding-requests" : 10009,
      "users-created" : 645,
      "datasets-created" : 147,
      "js-page-view" : 68095,
      "datasets-deleted" : 122,
      "rows-accessed-download" : 379,
      "view-loaded" : 16599,
      "app-token-created" : 1,
      "charts-deleted" : 17,
      "shares" : 1,
      "rows-loaded-rss" : 26698,
      "bytes-in" : 658003507,
      "filters-deleted" : 4985,
      "charts-created" : 16,
      "rows-created" : 1040389,
      "comments" : 2
    }

### Site-wide statistics by time interval (`series`)

    GET /api/site_metrics.json?method=series

If you want to get site-wide statistics by day, you could
use no method (above) and vary the start and end dates.
The series method lets you do something equivalent in one
HTTP request.

This method requires an additional parameter, `slice`.
Valid values include

* `DAILY`
* `WEEKLY`
* `MONTHLY`
* `YEARLY`

The result is a list of associative arrays, each one
corresponding to a time interval and containing the same
metrics that we would see with no method.

    curl 'https://data.oregon.gov/api/site_metrics.json?start=1375315200000&end=1376438399999&method=series&slice=WEEKLY'
    [ {
      "__start__" : 1374969600000,
      "metrics" : {
        ...
      },
      "__end__" : 1375574399999
    }, {
      "__start__" : 1375574400000,
      "metrics" : {
        ...
      },
      "__end__" : 1376179199999
    }, {
      ...
    } ]

### Most popular (`top`)

    GET /api/site_metrics.json?method=top

Return the most common entities of a particular type.
You specify the entity type with the required argument `top`;
it can be any of the following.

* `DATASETS`
* `REFERRERS`
* `SEARCHES`
* `EMBEDS`

The output is always an associative array, but the schema
depends on the type of entity.

#### Top datasets

    GET /api/site_metrics.json?method=top&top=DATASETS

This returns a mapping from 4x4 ids to some sort of count.
I presume that it's a view count, but it might be something
else, like a download count.

#### Top Referrers

    GET /api/site_metrics.json?method=top&top=REFERRERS

#### Top Searches

    GET /api/site_metrics.json?method=top&top=SEARCHES

Searches are separated into dataset searches and user searches.
Within each, a mapping from search terms to counts is returned.

#### Top Embeds

    GET /api/site_metrics.json?method=top&top=EMBEDS

This also returns counts of some sort. The root associative array
maps an origin (like `http://thomaslevine.com`) to an associative
array, and that child associative array maps the rest of the url
(like `<%= @item.identifier %>?foo=bar`) to a count.
