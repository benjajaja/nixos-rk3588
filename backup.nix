{ pkgs }: 
let 
  backupDir = "/srv/sdd/backups";
in
{
  description = "Sync Pictures and Documents to backup disk";
  conflicts = [ "matrix-synapse.service" ]; # Stop matrix on start.
  script = ''
    set -euo pipefail  # Exit on error, undefined variables, and pipe failures
    
    echo "Starting backup sync to ${backupDir} at $(date)"

    echo "Backing up vaultwarden..."
    ${pkgs.rsync}/bin/rsync -a --delete --mkpath /var/lib/vaultwarden/ ${backupDir}/vaultwarden/

    echo "Backing up backups share (quiet)..."
    ${pkgs.rsync}/bin/rsync -a --delete --mkpath /srv/backup/ ${backupDir}/backup/

    echo "Backing up photos (quiet)..."
    ${pkgs.rsync}/bin/rsync -a --delete --mkpath /srv/photos/ ${backupDir}/immich/photos/
    
    echo "Backing up Matrix Synapse secrets..."
    ${pkgs.rsync}/bin/rsync -av --delete --mkpath /var/lib/matrix-synapse/secrets ${backupDir}/matrix/secrets/

    echo "Backing up Matrix Synapse database..."
    ${pkgs.sqlite}/bin/sqlite3 /var/lib/matrix-synapse/homeserver.db ".backup ${backupDir}/matrix/homeserver.db"
    chown matrix-synapse:matrix-synapse ${backupDir}/matrix/homeserver.db
    chmod 600 ${backupDir}/matrix/homeserver.db
    
    echo "Backing up Matrix Synapse media_store (quiet)..."
    ${pkgs.rsync}/bin/rsync -a --delete --mkpath /var/lib/matrix-synapse/media_store ${backupDir}/matrix/media_store/
    
    echo "Backing up Matrix Synapse media_store (quiet)..."
    ${pkgs.rsync}/bin/rsync -a --delete --mkpath /var/lib/matrix-synapse/media_store ${backupDir}/matrix/media_store/
    
    echo "Backup sync completed successfully at $(date)"
  '';
  serviceConfig = {
    Type = "oneshot";
    User = "root";  # Needed for Matrix Synapse files
    Nice = 19;  # Low priority
    IOSchedulingClass = "idle";  # Low I/O priority
    StandardOutput = "journal";
    StandardError = "journal";
  };
  # Ensure matrix-synapse is started again after backup completes
  # (whether successful or failed)
  unitConfig = {
    OnSuccess = "matrix-synapse.service";
    OnFailure = "matrix-synapse.service";
  };
}
