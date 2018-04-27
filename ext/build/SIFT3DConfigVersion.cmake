################################################################################
# Copyright (c) 2015-2016 Blaine Rister et al., see LICENSE for details.
################################################################################
# SIFT3D package version file.
################################################################################

set (PACKAGE_VERSION 1.4.5)

# Check whether the requested PACKAGE_FIND_VERSION is compatible
if ("${PACKAGE_VERSION}" VERSION_LESS "${PACKAGE_FIND_VERSION}")
        set (PACKAGE_VERSION_COMPATIBLE FALSE)
else ()
        set (PACKAGE_VERSION_COMPATIBLE TRUE)
        if ("${PACKAGE_VERSION}" VERSION_EQUAL "${PACKAGE_FIND_VERSION}")
                set (PACKAGE_VERSION_EXACT TRUE)
        endif ()
endif ()
