from haystack.backends.elasticsearch7_backend import Elasticsearch7SearchBackend, Elasticsearch7SearchEngine


class Elasticsearch2IkSearchBackend(Elasticsearch7SearchBackend):

    def document_count(self):
        return self.conn.count(index=self.index_name)['count']


class Elasticsearch2IkSearchEngine(Elasticsearch7SearchEngine):
    backend = Elasticsearch2IkSearchBackend
