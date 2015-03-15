# Process Repository #

[Process](Process.md)es are stored in a repository which has a file system for storing files and a database for storing Processes.

Repository has a working area (named as **source** in the configuration file) and has a storage space (named as **target** in the configuration file). Working area and storage can be the same or be separated. It supports operations of registration, decommission and export. Because some operations involve copy which could take up lots of resource so when they are executed they run outside of the instance of repository. Storage can be a local directory or a network storage mounted locally. Features of a repository are:
  * It is a file system
  * It has a secured permanent storage
  * Registration of a [Process](Process.md) includes file transfer and metadata registration.
  * Files are transferred into a working area with an assigned account and then moved by another account to storage if there is a working area
  * It runs as services to clients, e.g. registration or export services
  * When registration services do not have access to storage, requests are generated
  * Registration service returns which account for scp and where to copy files when runs as a registration service
  * Files are named by their sha1 checksums
  * It stores metadata of files defined as [Process](Process.md) in database
  * Files are registered through registration of Process when they are in storage, not in working area
  * Files with same content (same checksum) different names have only one existence in storage but have multiple existences in database
  * Operations on repository involve copy are preferably carried out by other scripts outside service
  * On request, files can be physically deleted when they are the sole existence in the whole system through decommission
  * Files are never deleted from database
  * Files are exported on request as hard links when it is possible to only known locations. Otherwise they are copied
  * Files can be queried for existence (physical or just in database)
  * File query can be done by either original name or sha1 checksum

### Note ###
It is preferable to check if a file already exists to avoid unnecessary copy. When registration operating account does not have read permission to the storage, checking existence of files can be performed solely by querying database but file check is preferable. This can be done by having working area holds files, links or just names without content. When security is a concern, name-only method should be used to avoid the contents can be read. Under such setting no direct query to storage for existence is required when files are being registered. As files only have names in working area it is not possible to do checksum calculation for more comprehensive check. Therefore it is crucial the names (checksums) do reflect the files in storage. Maintaining working area is a task of system administrator who implements the system. For example, it is maintained by a daily job of repository operating account.