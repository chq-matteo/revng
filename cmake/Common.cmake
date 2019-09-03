macro(prepend_target_property TARGET PROPERTY VALUE SEPARATOR)
  get_target_property(TMP "${TARGET}" "${PROPERTY}")
  if(NOT "${TMP}" STREQUAL "")
    set(TMP "${SEPARATOR}${TMP}")
  endif()
  set_target_properties("${TARGET}" PROPERTIES "${PROPERTY}" "${VALUE}${TMP}")
endmacro()

macro(append_target_property TARGET PROPERTY VALUE SEPARATOR)
  get_target_property(TMP "${TARGET}" "${PROPERTY}")
  if(NOT "${TMP}" STREQUAL "")
    set(TMP "${TMP}${SEPARATOR}")
  endif()
  set_target_properties("${TARGET}" PROPERTIES "${PROPERTY}" "${TMP}${VALUE}")
endmacro()

macro(revng_add_library NAME TYPE EXPORT_NAME)

  add_library("${NAME}" "${TYPE}" ${ARGN})
  target_include_directories("${NAME}" INTERFACE $<INSTALL_INTERFACE:include/>)
  prepend_target_property("${NAME}" BUILD_RPATH "\$ORIGIN" ":")
  prepend_target_property("${NAME}" INSTALL_RPATH "\$ORIGIN" ":")

  make_directory("${CMAKE_BINARY_DIR}/lib/")
  add_custom_command(TARGET "${NAME}" POST_BUILD VERBATIM
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:${NAME}>" "${CMAKE_BINARY_DIR}/lib/$<TARGET_FILE_NAME:${NAME}>")

  install(TARGETS "${NAME}"
    EXPORT "${EXPORT_NAME}"
    LIBRARY DESTINATION lib/
    ARCHIVE DESTINATION lib/)

endmacro()

# Helper macro to create a new library containing analyses to be employed in
# revng-opt
macro(revng_add_analyses_library NAME EXPORT_NAME)

  add_library("${NAME}" SHARED ${ARGN})
  target_include_directories("${NAME}" INTERFACE $<INSTALL_INTERFACE:include/>)
  prepend_target_property("${NAME}" BUILD_RPATH "\$ORIGIN/../../:\$ORIGIN" ":")
  prepend_target_property("${NAME}" INSTALL_RPATH "\$ORIGIN/../../:\$ORIGIN" ":")

  make_directory("${CMAKE_BINARY_DIR}/lib/revng/analyses/")
  add_custom_command(TARGET "${NAME}" POST_BUILD VERBATIM
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:${NAME}>" "${CMAKE_BINARY_DIR}/lib/revng/analyses/$<TARGET_FILE_NAME:${NAME}>")

  install(TARGETS "${NAME}" EXPORT "${EXPORT_NAME}" LIBRARY DESTINATION lib/revng/analyses)

endmacro()

macro(revng_add_executable NAME)

  add_executable("${NAME}" ${ARGN})
  prepend_target_property("${NAME}" BUILD_RPATH "\$ORIGIN/../lib/:\$ORIGIN/../lib/revng/analyses/" ":")
  prepend_target_property("${NAME}" INSTALL_RPATH "\$ORIGIN/../lib/:\$ORIGIN/../lib/revng/analyses/" ":")

  make_directory("${CMAKE_BINARY_DIR}/bin/")
  add_custom_command(TARGET "${NAME}" POST_BUILD VERBATIM
    COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:${NAME}>" "${CMAKE_BINARY_DIR}/bin/$<TARGET_FILE_NAME:${NAME}>")

  install(TARGETS "${NAME}" RUNTIME DESTINATION bin)

endmacro()

# This macro returns in ${RESULT} a list of files matching the pattern in the
# extra arguments. If the source is in a git repository, only tracked files are
# returned, otherwise a regular globbing expression is employed.
macro(git_ls_files_or_glob RESULT)

  execute_process(COMMAND git ls-files ${ARGN}
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    RESULT_VARIABLE GIT_LS_EXIT_CODE
    OUTPUT_VARIABLE GIT_LS_OUTPUT
    ERROR_VARIABLE GIT_LS_OUTPUT_STDERR)

  if(GIT_LS_EXIT_CODE EQUAL "0")
    string(REGEX REPLACE "\n" ";" ${RESULT} "${GIT_LS_OUTPUT}")
  else()
    file(GLOB_RECURSE ${RESULT} RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" ${ARGN})
  endif()

endmacro(git_ls_files_or_glob)

# This macro installs all the files matching the pattern in the extra arguments
macro(install_pattern)

  git_ls_files_or_glob(HEADERS_TO_INSTALL ${ARGN})

  file(RELATIVE_PATH RELATIVE_SOURCE_DIR ${CMAKE_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR})

  foreach(FILE ${HEADERS_TO_INSTALL})
    get_filename_component(INSTALL_PATH "${FILE}" DIRECTORY)
    install(FILES "${FILE}" DESTINATION ${RELATIVE_SOURCE_DIR}/${INSTALL_PATH})
  endforeach(FILE)

endmacro(install_pattern)
