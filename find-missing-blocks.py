from elasticsearch import Elasticsearch
from packaging import version
import time
import sys

if len(sys.argv) != 3:
  raise ValueError('Please provide chain name, Elastic username, password and Elastic IP address. http://elastic:password@127.0.0.1:9200')
chain = sys.argv[1]
elasticnode = sys.argv[2]

index_pattern = f'{chain}-block-*'

es = Elasticsearch(
  [
    elasticnode
  ],
  verify_certs=True
)

es_info = es.info()
es_version = es_info['version']['number']


def query_body(interval):
  query_body = {
    "aggs": {
      "block_histogram": {
        "histogram": {
          "field": "block_num",
          "interval": interval,
          "min_doc_count": 0
        },
        "aggs": {
          "max_block": {
            "max": {
              "field": "block_num"
            }
          }
        }
      }
    },
    "size": 0,
    "query": {
      "match_all": {}
    }
  }
  return query_body

def query_body2(gte, lte, interval):
  query = {
    "aggs": {
      "block_histogram": {
        "histogram": {
          "field": "block_num",
          "interval": interval,
          "min_doc_count": 0,
          "extended_bounds": {
            "min": gte,
            "max": lte
          }
        },
        "aggs": {
          "max_block": {
            "max": {
              "field": "block_num"
            }
          }
        }
      }
    },
    "size": 0,
    "query": {
      "bool": {
        "must": [
          {
            "range": {
              "block_num": {
                "gte": gte,
                "lte": lte
              }
            }
          }
        ]
      }
    }
  }
  return query

# Search and return buckets
def get_buckets(interval, query):
  query = query(interval)
  if version.parse(es_version) < version.parse('8'):
    result = es.search(timeout = '600s', index = index_pattern, body = query)
  else:
    result = es.search(timeout = '600s', index = index_pattern, query = query['query'], aggs = query['aggs'], size = query['size'])
  buckets = result['aggregations']['block_histogram']['buckets']
  return buckets

# Find buckets with missing blocks
def buckets_missing(bucketlist, count1, count2): 
  buckets_final = []
  bucketdict = {}
  for num, bucket in enumerate(bucketlist):
    # Create copy of dict and call it new
    new = bucketdict.copy()
    key = bucket['key']
    doc_count = bucket['doc_count']
    # Check if count is less than
    if num == 0 and doc_count < count1:
      new.update({'key': key, 'doc_count': doc_count})
      buckets_final.append(new)
    # If not first bucket but has less than count2
    elif doc_count < count2 and num != 0:
      new.update({'key': key, 'doc_count': doc_count})
      buckets_final.append(new)
  return buckets_final

# Create greater, less than lists for missing buckets.
def CreateMissingGTLT(missing, bucket_size, interval):
  buckets_final = []
  bucketdict = {}
  lte = interval
  for num, bucket in enumerate(missing):
    gte = bucket['key']
    lte = gte + lte
    query = query_body2(gte, lte, bucket_size)
    if version.parse(es_version) < version.parse('8'):
      result = es.search(timeout = '600s', index = index_pattern, body = query)
    else:
      result = es.search(timeout = '600s', index = index_pattern, query = query['query'], aggs = query['aggs'], size = query['size'])
    buckets = result['aggregations']['block_histogram']['buckets']
    missing = buckets_missing(buckets, bucket_size, bucket_size)
    for bucket in missing:
      new = bucketdict.copy()
      doc_count = bucket['doc_count']
      gt = bucket['key']
      lt = gt + bucket_size
      new.update({'gt': gt, 'lt': lt, 'doc_count': doc_count})
      buckets_final.append(new)
  return buckets_final


# Find buckets with existing blocks
def buckets_existing(bucketlist, bucket_size, min_key): 
  buckets_final = []
  for bucket in bucketlist:
    # Create copy of dict and call it new
    key = bucket['key']
    if key > min_key or (key + bucket_size) > min_key:
      doc_count = bucket['doc_count']
      # Check if count is greater than 0
      if doc_count > 0:
        buckets_final.append({'key': key, 'doc_count': doc_count})
  return buckets_final

# Find next existing after block min_key
def FindExisting(existing, bucket_size, min_key):
  new_existing = buckets_existing(existing, bucket_size, min_key)
  if bucket_size == 1:
    return new_existing

  for which_range, block_range in enumerate(new_existing):
    key = block_range['key']
    if key > min_key or (key + bucket_size) > min_key:
      # recurse in this block_range
      query = query_body2(key, key + bucket_size, int(bucket_size / 10))
      if version.parse(es_version) < version.parse('8'):
        result = es.search(timeout = '600s', index = index_pattern, body = query)
      else:
        result = es.search(timeout = '600s', index = index_pattern, query = query['query'], aggs = query['aggs'], size = query['size'])
      buckets = result['aggregations']['block_histogram']['buckets']
      new_buckets = FindExisting(buckets, int(bucket_size / 10), min_key)
      if len(new_buckets) > 0:
        return new_buckets

  return []


if __name__ == '__main__':
  try:
    # Search for missing buckets using histogram interval
    bucket_size = 10000000
    buckets = get_buckets(bucket_size, query_body)
    # Get buckets with missing blocks, first count is 9999998 to account for bucket 0-9999999.
    # Hyperion 3.1.4 does index block 2 so we get 9999999 blocks in the first bucket.
    # Hyperion 3.3.5 does not index block 2 so we only get 9999998 blocks in the first bucket.
    missing = buckets_missing(buckets, bucket_size - 2, bucket_size)
    first_missing_block = None
    next_existing_block = None
    interval = bucket_size
    bucket_size = interval / 10
    gt_lt_list = CreateMissingGTLT(missing, bucket_size, interval)
    while bucket_size > 0:
      if len(gt_lt_list) == 0:
        break
      else:
        for i in range(1, len(gt_lt_list)):
          if gt_lt_list[i]['doc_count'] > 0:
            break
        first_block = gt_lt_list[0]['gt']
        missing = {}
        missing['key'] = first_block
        interval = interval / 10
        bucket_size = bucket_size / 10
        gt_lt_list = CreateMissingGTLT([missing], bucket_size, interval)
        if len(gt_lt_list) == 0:
          break
        if bucket_size <= 1:
          first_missing_block = gt_lt_list[0]['gt']
          break

    if first_missing_block != None:
      # There is no block 0 - jump over it if selected.
      if first_missing_block == 0:
        first_missing_block = 1
      # Search for existing buckets using histogram interval
      bucket_size = 10000000
      buckets = get_buckets(bucket_size, query_body)
      existing = FindExisting(buckets, bucket_size, first_missing_block)
      if len(existing) > 0:
        next_existing_block = existing[0]['key']

    print('Gap:', end='')
    if first_missing_block == None or first_missing_block == next_existing_block:
      print('None', end='')
    else:
      print(f'{int(first_missing_block)}', end='')
    print(':', end='')
    if next_existing_block == None or first_missing_block == next_existing_block:
      print('None', end='')
    else:
      print(f'{int(next_existing_block)}', end='')
    print()
    if first_missing_block == None or next_existing_block == None or first_missing_block == next_existing_block:
      # We failed to find a gap.
      sys.exit(1)
  except KeyboardInterrupt:
    print('Gap:None:Interrupted')
    sys.exit(1)
