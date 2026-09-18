#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "MAVSDK::mavsdk" for configuration "Release"
set_property(TARGET MAVSDK::mavsdk APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(MAVSDK::mavsdk PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libmavsdk.so.3.17.4"
  IMPORTED_SONAME_RELEASE "libmavsdk.so.3"
  )

list(APPEND _IMPORT_CHECK_TARGETS MAVSDK::mavsdk )
list(APPEND _IMPORT_CHECK_FILES_FOR_MAVSDK::mavsdk "${_IMPORT_PREFIX}/lib/libmavsdk.so.3.17.4" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
