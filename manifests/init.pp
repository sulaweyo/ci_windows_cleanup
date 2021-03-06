# Class: ci_windows_cleanup
#   Parameter: user - defaults to Administrator, used to define the directory we want to delete
#
class ci_windows_cleanup ($user = 'Administrator') {

  # in my environment around noon is kind of low load so let's schedule it here
  schedule { 'ci_windows_cleanup':
    range  => "10 - 14",
    period => daily,
    repeat => 1,
  }

  if $::kernel == 'windows' {
    # Define the path to the temp directory
    if $::kernelmajorversion >= '6.0' {
      $temp_path = "C:\\Users\\${user}\\AppData\\Local\\Temp"
    } else {
      $temp_path = "C:\\Documents and Settings\\${user}\\Local Settings\\Temp"
    }
    # Purge the %TEMP% directory completely. Some files might be locked as they are used so we accept more exit codes.
    exec { 'windows_cleanup_purge_temp':
      command   => "cmd /c rmdir /s/q ${temp_path}",
      path      => $::path,
      cwd       => "${temp_path}\\..\\", # change into TEMPs parent folder to run the cleanup command
      logoutput => false, # we delete quiet so nothing interesting here in the first place
      timeout   => 900, # 15 minutes are enough, if not we come back here tomorrow anyway
      returns   => [0, 5, 32], # 0 success, 5 access denied, 32 sharing violation -> all fine as everything not in use got deleted
      notify    => Exec['windows_cleanup_recreate_temp'], # trigger the recreation of the directory
      schedule  => 'ci_windows_cleanup'
    }

    # As we purged the %TEMP% directory we have to recreate it to not break
    exec { 'windows_cleanup_recreate_temp':
      command     => "cmd /c mkdir ${temp_path}",
      path        => $::path,
      returns     => [0, 1], # if the dir already exists we are fine too
      refreshonly => true,
    }

    # Empty the recycle bin on %systemdrive% as well
    exec { 'windows_cleanup_purge_recycle_bin':
      command   => "cmd /c rmdir /s/q %systemdrive%\\\$Recycle.bin",
      path      => $::path,
      logoutput => false, # we delete quiet so nothing interesting here in the first place
      timeout   => 900, # 15 minutes are enough, if not we come back here tomorrow anyway
      returns   => [0, 5, 32], # 0 success, 5 access denied, 32 sharing violation -> all fine as everything not in use got deleted
      schedule  => 'ci_windows_cleanup'
    }

  } else {
    debug 'This class is usable for windows only!'
  }
}
