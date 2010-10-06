#---+ Extensions
#---++ DBCacheContrib
# This extension is a database cache, used by the DBCachePlugin
# and FormQueryPlugin.

# **SELECTCLASS Foswiki::Contrib::DBCacheContrib::Archivist::* **
# The DBCache can use one of a number of different back-end stores.
# Which one you choose depends mainly on what you
# have installed, and what your data looks like. If you have a realtively
# small number of topics (< 5000) and lots of memory, you should use the
# 'Storable' module. This module loads all topic data into memory for fast
# searching. On the other hand, if you have a large number of topics, or tight
# memory constraints, you should use 'BerkeleyDB' which stores the cache in
# an external database. This is slightly slower to search, but is scalable
# up to very large numbers of topics.
$Foswiki::cfg{DBCacheContrib}{Archivist} =
    'Foswiki::Contrib::DBCacheContrib::Archivist::Storable';

# **BOOLEAN**
# When cleared, then do not update the cache from the .txt files unless
# explicitly requested by the calling code. The default is to update it
# automatically whenever the database is opened.
# Normally this should be set according to the directions given for
# installing the extension that is providing the interface to the DBCache.
$Foswiki::cfg{DBCacheContrib}{AlwaysUpdateCache} = $TRUE;

# **NUMBER**
# With a load limit of 0 the DBCache will reload all the changed
# and new files in one hit. This can impose a significant overhead if a lot
# of files change. Set this option to a positive number to limit the number
# of files updated during any given HTTP request, thus reducing the impact on
# individual topic views by spreading the update over several requests.
# Normally this should be set according to the directions given for
# installing whatever extension is providing the interface to the DBCache.
$Foswiki::cfg{DBCacheContrib}{LoadFileLimit} = 0;
