class CacheEntry<T> {
  final T value;
  final DateTime storedAt;

  CacheEntry(this.value) : storedAt = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(storedAt) > ttl;
}
