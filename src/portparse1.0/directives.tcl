# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
# directives.tcl
#
# MacPorts directive classification table as pure data. Keyed by directive
# name; values are {sets <list-of-fields> category <cat>}. Query procs live
# in classify.tcl; this file is intentionally just data so reviewing
# directive additions is a focused diff.
#
# Categories (closed enum, declared order matters — see
# [portparse::categories]):
#     identity metadata source dependency build-config phase
#
# Each entry carries a trailing comment naming the src/port1.0/*.tcl file
# it comes from. When the drift test (Phase 12) flags a missing directive,
# add the entry here in sorted order with the correct category.
#
# =========================================================================
# Known dynamic-name families — CI-UNVERIFIABLE.
# =========================================================================
#
# The drift test scans port1.0 for registration calls with string-literal
# name arguments. Some directives are registered dynamically (variable
# refs, {*}$list expansion) — the scanner sees only the call site, not the
# names produced. It emits a warning when a new dynamic call site appears,
# but does NOT fire when maintainers add new *members* to an existing
# dynamic family. That gap is the responsibility of whoever edits the
# families below.
#
# If you touch any of these source locations, re-read this block and
# reconcile the table by hand.
#
#   portextract.tcl — `{*}${portextract::all_use_options}` expansion in
#       the `options` call near line 52. The list is defined near line 44:
#           variable all_use_options [list use_7z use_bzip2 use_dmg
#               use_lzip use_lzma use_tar use_xz use_zip]
#       Adding a new member to that list means adding a matching
#       `use_<NAME>` entry here.
#
#   portconfigure.tcl — `foreach _portconfigure_tool {cc objc f77 f90 fc}`
#       near line 310 registers `configure.<tool>_archflags`. Adding a
#       tool to that foreach means adding a matching
#       `configure.<tool>_archflags` entry here. (Note: `configure.cxx_archflags`
#       and `configure.objcxx_archflags` are registered statically at
#       lines 54/58 and are already caught by the drift test.)
#
# =========================================================================

namespace eval portparse {
    variable _directives [dict create]
    variable _categories [list identity metadata source dependency build-config phase]
}

# Every directive below is registered in src/port1.0/*.tcl and is in
# sorted order. See comments on the right naming the source file.

dict set portparse::_directives PortGroup                                                {sets {PortGroup} category metadata}      ;# portmain.tcl
dict set portparse::_directives PortSystem                                               {sets {PortSystem} category metadata}      ;# portmain.tcl
dict set portparse::_directives activate.asroot                                          {sets {activate.asroot} category phase}         ;# portactivate.tcl
dict set portparse::_directives add_users                                                {sets {add_users} category metadata}      ;# portmain.tcl
dict set portparse::_directives autoconf.args                                            {sets {autoconf.args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.cmd                                             {sets {autoconf.cmd} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.dir                                             {sets {autoconf.dir} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.env                                             {sets {autoconf.env} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.nice                                            {sets {autoconf.nice} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.post_args                                       {sets {autoconf.post_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.pre_args                                        {sets {autoconf.pre_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoconf.type                                            {sets {autoconf.type} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.args                                            {sets {automake.args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.cmd                                             {sets {automake.cmd} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.dir                                             {sets {automake.dir} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.env                                             {sets {automake.env} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.nice                                            {sets {automake.nice} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.post_args                                       {sets {automake.post_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.pre_args                                        {sets {automake.pre_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives automake.type                                            {sets {automake.type} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.args                                          {sets {autoreconf.args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.cmd                                           {sets {autoreconf.cmd} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.dir                                           {sets {autoreconf.dir} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.env                                           {sets {autoreconf.env} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.nice                                          {sets {autoreconf.nice} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.post_args                                     {sets {autoreconf.post_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.pre_args                                      {sets {autoreconf.pre_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives autoreconf.type                                          {sets {autoreconf.type} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives build                                                    {sets {build} category phase}         ;# portbuild.tcl (phase-override body)
dict set portparse::_directives build.args                                               {sets {build.args} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.asroot                                             {sets {build.asroot} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.cmd                                                {sets {build.cmd} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.dir                                                {sets {build.dir} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.env                                                {sets {build.env} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.jobs                                               {sets {build.jobs} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.jobs_arg                                           {sets {build.jobs_arg} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.mem_per_job                                        {sets {build.mem_per_job} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.nice                                               {sets {build.nice} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.post_args                                          {sets {build.post_args} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.pre_args                                           {sets {build.pre_args} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.target                                             {sets {build.target} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.type                                               {sets {build.type} category build-config}  ;# portbuild.tcl
dict set portparse::_directives build.type.add_deps                                      {sets {build.type.add_deps} category build-config}  ;# portbuild.tcl
dict set portparse::_directives bzr.args                                                 {sets {bzr.args} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.cmd                                                  {sets {bzr.cmd} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.dir                                                  {sets {bzr.dir} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.env                                                  {sets {bzr.env} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.nice                                                 {sets {bzr.nice} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.post_args                                            {sets {bzr.post_args} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.pre_args                                             {sets {bzr.pre_args} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.revision                                             {sets {bzr.revision} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.type                                                 {sets {bzr.type} category source}        ;# portfetch.tcl
dict set portparse::_directives bzr.url                                                  {sets {bzr.url} category source}        ;# portfetch.tcl
dict set portparse::_directives categories                                               {sets {categories} category metadata}      ;# portmain.tcl
dict set portparse::_directives checksum.skip                                            {sets {checksum.skip} category source}        ;# portchecksum.tcl
dict set portparse::_directives checksums                                                {sets {checksums} category source}        ;# portchecksum.tcl
dict set portparse::_directives compiler.blacklist                                       {sets {compiler.blacklist} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.c_standard                                      {sets {compiler.c_standard} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.cpath                                           {sets {compiler.cpath} category metadata}      ;# portmain.tcl
dict set portparse::_directives compiler.cxx_standard                                    {sets {compiler.cxx_standard} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.fallback                                        {sets {compiler.fallback} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.fortran_fallback                                {sets {compiler.fortran_fallback} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.library_path                                    {sets {compiler.library_path} category metadata}      ;# portmain.tcl
dict set portparse::_directives compiler.limit_flags                                     {sets {compiler.limit_flags} category metadata}      ;# portmain.tcl
dict set portparse::_directives compiler.log_verbose_output                              {sets {compiler.log_verbose_output} category metadata}      ;# portmain.tcl
dict set portparse::_directives compiler.mpi                                             {sets {compiler.mpi} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.openmp_version                                  {sets {compiler.openmp_version} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.require_fortran                                 {sets {compiler.require_fortran} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.support_environment_paths                       {sets {compiler.support_environment_paths} category metadata}      ;# portmain.tcl
dict set portparse::_directives compiler.support_environment_sdkroot                     {sets {compiler.support_environment_sdkroot} category metadata}      ;# portmain.tcl
dict set portparse::_directives compiler.thread_local_storage                            {sets {compiler.thread_local_storage} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives compiler.whitelist                                       {sets {compiler.whitelist} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure                                                {sets {configure} category phase}         ;# portconfigure.tcl (phase-override body)
dict set portparse::_directives configure.args                                           {sets {configure.args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.asroot                                         {sets {configure.asroot} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.awk                                            {sets {configure.awk} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.bison                                          {sets {configure.bison} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.build_arch                                     {sets {configure.build_arch} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cc                                             {sets {configure.cc} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cc_archflags                                   {sets {configure.cc_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.ccache                                         {sets {configure.ccache} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cflags                                         {sets {configure.cflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.checks.implicit_function_declaration           {sets {configure.checks.implicit_function_declaration} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.checks.implicit_function_declaration.whitelist {sets {configure.checks.implicit_function_declaration.whitelist} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.checks.implicit_int                            {sets {configure.checks.implicit_int} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.checks.incompatible_function_pointer_types     {sets {configure.checks.incompatible_function_pointer_types} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.classpath                                      {sets {configure.classpath} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cmd                                            {sets {configure.cmd} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.compiler                                       {sets {configure.compiler} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.compiler.add_deps                              {sets {configure.compiler.add_deps} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cpp                                            {sets {configure.cpp} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cppflags                                       {sets {configure.cppflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cxx                                            {sets {configure.cxx} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cxx_archflags                                  {sets {configure.cxx_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cxx_stdlib                                     {sets {configure.cxx_stdlib} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.cxxflags                                       {sets {configure.cxxflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.developer_dir                                  {sets {configure.developer_dir} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.dir                                            {sets {configure.dir} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.distcc                                         {sets {configure.distcc} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.env                                            {sets {configure.env} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.f77                                            {sets {configure.f77} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.f77_archflags                                  {sets {configure.f77_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.f90                                            {sets {configure.f90} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.f90_archflags                                  {sets {configure.f90_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.f90flags                                       {sets {configure.f90flags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.fc                                             {sets {configure.fc} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.fc_archflags                                   {sets {configure.fc_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.fcflags                                        {sets {configure.fcflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.fflags                                         {sets {configure.fflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.install                                        {sets {configure.install} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.javac                                          {sets {configure.javac} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.ld_archflags                                   {sets {configure.ld_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.ldflags                                        {sets {configure.ldflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.libs                                           {sets {configure.libs} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.m32                                            {sets {configure.m32} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.m64                                            {sets {configure.m64} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.march                                          {sets {configure.march} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.mtune                                          {sets {configure.mtune} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.nice                                           {sets {configure.nice} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.objc                                           {sets {configure.objc} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.objc_archflags                                 {sets {configure.objc_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.objcflags                                      {sets {configure.objcflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.objcxx                                         {sets {configure.objcxx} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.objcxx_archflags                               {sets {configure.objcxx_archflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.objcxxflags                                    {sets {configure.objcxxflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.optflags                                       {sets {configure.optflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.perl                                           {sets {configure.perl} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.pipe                                           {sets {configure.pipe} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.pkg_config                                     {sets {configure.pkg_config} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.pkg_config_path                                {sets {configure.pkg_config_path} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.post_args                                      {sets {configure.post_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.pre_args                                       {sets {configure.pre_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.python                                         {sets {configure.python} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.ruby                                           {sets {configure.ruby} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.sdk_version                                    {sets {configure.sdk_version} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.sdkroot                                        {sets {configure.sdkroot} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.sysroot                                        {sets {configure.sysroot} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.type                                           {sets {configure.type} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_archs                                {sets {configure.universal_archs} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_args                                 {sets {configure.universal_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_cflags                               {sets {configure.universal_cflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_cppflags                             {sets {configure.universal_cppflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_cxxflags                             {sets {configure.universal_cxxflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_ldflags                              {sets {configure.universal_ldflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_objcflags                            {sets {configure.universal_objcflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives configure.universal_objcxxflags                          {sets {configure.universal_objcxxflags} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives conflicts                                                {sets {conflicts} category dependency}    ;# portmain.tcl
dict set portparse::_directives copy_log_files                                           {sets {copy_log_files} category metadata}      ;# portmain.tcl
dict set portparse::_directives cvs.args                                                 {sets {cvs.args} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.cmd                                                  {sets {cvs.cmd} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.date                                                 {sets {cvs.date} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.dir                                                  {sets {cvs.dir} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.env                                                  {sets {cvs.env} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.method                                               {sets {cvs.method} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.module                                               {sets {cvs.module} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.nice                                                 {sets {cvs.nice} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.password                                             {sets {cvs.password} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.post_args                                            {sets {cvs.post_args} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.pre_args                                             {sets {cvs.pre_args} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.root                                                 {sets {cvs.root} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.tag                                                  {sets {cvs.tag} category source}        ;# portfetch.tcl
dict set portparse::_directives cvs.type                                                 {sets {cvs.type} category source}        ;# portfetch.tcl
dict set portparse::_directives deactivate.asroot                                        {sets {deactivate.asroot} category phase}         ;# portdeactivate.tcl
dict set portparse::_directives default_variants                                         {sets {default_variants} category metadata}      ;# portmain.tcl
dict set portparse::_directives depends                                                  {sets {depends} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_build                                            {sets {depends_build} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_extract                                          {sets {depends_extract} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_fetch                                            {sets {depends_fetch} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_lib                                              {sets {depends_lib} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_patch                                            {sets {depends_patch} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_run                                              {sets {depends_run} category dependency}    ;# portdepends.tcl
dict set portparse::_directives depends_skip_archcheck                                   {sets {depends_skip_archcheck} category dependency}    ;# portmain.tcl
dict set portparse::_directives depends_test                                             {sets {depends_test} category dependency}    ;# portdepends.tcl
dict set portparse::_directives description                                              {sets {description} category metadata}      ;# portmain.tcl
dict set portparse::_directives destroot                                                 {sets {destroot} category phase}         ;# portdestroot.tcl (phase-override body)
dict set portparse::_directives destroot.args                                            {sets {destroot.args} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.asroot                                          {sets {destroot.asroot} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.clean                                           {sets {destroot.clean} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.cmd                                             {sets {destroot.cmd} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.delete_la_files                                 {sets {destroot.delete_la_files} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.destdir                                         {sets {destroot.destdir} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.dir                                             {sets {destroot.dir} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.env                                             {sets {destroot.env} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.keepdirs                                        {sets {destroot.keepdirs} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.nice                                            {sets {destroot.nice} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.post_args                                       {sets {destroot.post_args} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.pre_args                                        {sets {destroot.pre_args} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.target                                          {sets {destroot.target} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.type                                            {sets {destroot.type} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.umask                                           {sets {destroot.umask} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives destroot.violate_mtree                                   {sets {destroot.violate_mtree} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives dist_subdir                                              {sets {dist_subdir} category source}        ;# portfetch.tcl
dict set portparse::_directives distcheck.type                                           {sets {distcheck.type} category phase}         ;# portdistcheck.tcl
dict set portparse::_directives distfiles                                                {sets {distfiles} category source}        ;# portfetch.tcl
dict set portparse::_directives distname                                                 {sets {distname} category metadata}      ;# portmain.tcl
dict set portparse::_directives distpath                                                 {sets {distpath} category metadata}      ;# portmain.tcl
dict set portparse::_directives epoch                                                    {sets {epoch} category identity}      ;# portmain.tcl
dict set portparse::_directives extract.add_deps                                         {sets {extract.add_deps} category source}        ;# portextract.tcl
dict set portparse::_directives extract.args                                             {sets {extract.args} category source}        ;# portextract.tcl
dict set portparse::_directives extract.asroot                                           {sets {extract.asroot} category source}        ;# portextract.tcl
dict set portparse::_directives extract.cmd                                              {sets {extract.cmd} category source}        ;# portextract.tcl
dict set portparse::_directives extract.dir                                              {sets {extract.dir} category source}        ;# portextract.tcl
dict set portparse::_directives extract.env                                              {sets {extract.env} category source}        ;# portextract.tcl
dict set portparse::_directives extract.methods                                          {sets {extract.methods} category source}        ;# portextract.tcl
dict set portparse::_directives extract.mkdir                                            {sets {extract.mkdir} category source}        ;# portextract.tcl
dict set portparse::_directives extract.nice                                             {sets {extract.nice} category source}        ;# portextract.tcl
dict set portparse::_directives extract.only                                             {sets {extract.only} category source}        ;# portextract.tcl
dict set portparse::_directives extract.post_args                                        {sets {extract.post_args} category source}        ;# portextract.tcl
dict set portparse::_directives extract.pre_args                                         {sets {extract.pre_args} category source}        ;# portextract.tcl
dict set portparse::_directives extract.rename                                           {sets {extract.rename} category source}        ;# portextract.tcl
dict set portparse::_directives extract.suffix                                           {sets {extract.suffix} category source}        ;# portextract.tcl
dict set portparse::_directives extract.type                                             {sets {extract.type} category source}        ;# portextract.tcl
dict set portparse::_directives fetch.ignore_sslcert                                     {sets {fetch.ignore_sslcert} category source}        ;# portfetch.tcl
dict set portparse::_directives fetch.password                                           {sets {fetch.password} category source}        ;# portfetch.tcl
dict set portparse::_directives fetch.type                                               {sets {fetch.type} category source}        ;# portfetch.tcl
dict set portparse::_directives fetch.use_epsv                                           {sets {fetch.use_epsv} category source}        ;# portfetch.tcl
dict set portparse::_directives fetch.user                                               {sets {fetch.user} category source}        ;# portfetch.tcl
dict set portparse::_directives fetch.user_agent                                         {sets {fetch.user_agent} category source}        ;# portfetch.tcl
dict set portparse::_directives filesdir                                                 {sets {filesdir} category metadata}      ;# portmain.tcl
dict set portparse::_directives git.branch                                               {sets {git.branch} category source}        ;# portfetch.tcl
dict set portparse::_directives git.cmd                                                  {sets {git.cmd} category source}        ;# portfetch.tcl
dict set portparse::_directives git.url                                                  {sets {git.url} category source}        ;# portfetch.tcl
dict set portparse::_directives hg.cmd                                                   {sets {hg.cmd} category source}        ;# portfetch.tcl
dict set portparse::_directives hg.tag                                                   {sets {hg.tag} category source}        ;# portfetch.tcl
dict set portparse::_directives hg.url                                                   {sets {hg.url} category source}        ;# portfetch.tcl
dict set portparse::_directives homepage                                                 {sets {homepage} category metadata}      ;# portmain.tcl
dict set portparse::_directives install.asroot                                           {sets {install.asroot} category phase}         ;# portinstall.tcl
dict set portparse::_directives install.group                                            {sets {install.group} category metadata}      ;# portmain.tcl
dict set portparse::_directives install.user                                             {sets {install.user} category metadata}      ;# portmain.tcl
dict set portparse::_directives installs_libs                                            {sets {installs_libs} category metadata}      ;# portmain.tcl
dict set portparse::_directives known_fail                                               {sets {known_fail} category metadata}      ;# portmain.tcl
dict set portparse::_directives libpath                                                  {sets {libpath} category metadata}      ;# portmain.tcl
dict set portparse::_directives license                                                  {sets {license} category metadata}      ;# portmain.tcl
dict set portparse::_directives license_noconflict                                       {sets {license_noconflict} category metadata}      ;# portmain.tcl
dict set portparse::_directives livecheck.branch                                         {sets {livecheck.branch} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.compression                                    {sets {livecheck.compression} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.curloptions                                    {sets {livecheck.curloptions} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.distname                                       {sets {livecheck.distname} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.ignore_sslcert                                 {sets {livecheck.ignore_sslcert} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.md5                                            {sets {livecheck.md5} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.name                                           {sets {livecheck.name} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.regex                                          {sets {livecheck.regex} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.type                                           {sets {livecheck.type} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.url                                            {sets {livecheck.url} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.user_agent                                     {sets {livecheck.user_agent} category source}        ;# portlivecheck.tcl
dict set portparse::_directives livecheck.version                                        {sets {livecheck.version} category source}        ;# portlivecheck.tcl
dict set portparse::_directives load.asroot                                              {sets {load.asroot} category phase}         ;# portload.tcl
dict set portparse::_directives long_description                                         {sets {long_description} category metadata}      ;# portmain.tcl
dict set portparse::_directives macosx_deployment_target                                 {sets {macosx_deployment_target} category metadata}      ;# portmain.tcl
dict set portparse::_directives maintainers                                              {sets {maintainers} category metadata}      ;# portmain.tcl
dict set portparse::_directives master_sites                                             {sets {master_sites} category source}        ;# portfetch.tcl
dict set portparse::_directives master_sites.mirror_subdir                               {sets {master_sites.mirror_subdir} category source}        ;# portfetch.tcl
dict set portparse::_directives name                                                     {sets {name} category identity}      ;# portmain.tcl
dict set portparse::_directives notes                                                    {sets {notes} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.arch                                                  {sets {os.arch} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.endian                                                {sets {os.endian} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.major                                                 {sets {os.major} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.minor                                                 {sets {os.minor} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.platform                                              {sets {os.platform} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.subplatform                                           {sets {os.subplatform} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.universal_supported                                   {sets {os.universal_supported} category metadata}      ;# portmain.tcl
dict set portparse::_directives os.version                                               {sets {os.version} category metadata}      ;# portmain.tcl
dict set portparse::_directives patch.args                                               {sets {patch.args} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.asroot                                             {sets {patch.asroot} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.cmd                                                {sets {patch.cmd} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.dir                                                {sets {patch.dir} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.env                                                {sets {patch.env} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.nice                                               {sets {patch.nice} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.post_args                                          {sets {patch.post_args} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.pre_args                                           {sets {patch.pre_args} category source}        ;# portpatch.tcl
dict set portparse::_directives patch.type                                               {sets {patch.type} category source}        ;# portpatch.tcl
dict set portparse::_directives patch_sites                                              {sets {patch_sites} category source}        ;# portfetch.tcl
dict set portparse::_directives patch_sites.mirror_subdir                                {sets {patch_sites.mirror_subdir} category source}        ;# portfetch.tcl
dict set portparse::_directives patchfiles                                               {sets {patchfiles} category source}        ;# portfetch.tcl
dict set portparse::_directives platform                                                 {sets {platform} category phase}         ;# portmain.tcl
dict set portparse::_directives platforms                                                {sets {platforms} category metadata}      ;# portmain.tcl
dict set portparse::_directives portdbpath                                               {sets {portdbpath} category metadata}      ;# portmain.tcl
dict set portparse::_directives portsandbox_active                                       {sets {portsandbox_active} category phase}         ;# portsandbox.tcl
dict set portparse::_directives portsandbox_profile                                      {sets {portsandbox_profile} category phase}         ;# portsandbox.tcl
dict set portparse::_directives portsandbox_supported                                    {sets {portsandbox_supported} category phase}         ;# portsandbox.tcl
dict set portparse::_directives post-activate                                            {sets {post-activate} category phase}         ;# portutil.tcl
dict set portparse::_directives post-build                                               {sets {post-build} category phase}         ;# portutil.tcl
dict set portparse::_directives post-checksum                                            {sets {post-checksum} category phase}         ;# portutil.tcl
dict set portparse::_directives post-configure                                           {sets {post-configure} category phase}         ;# portutil.tcl
dict set portparse::_directives post-deactivate                                          {sets {post-deactivate} category phase}         ;# portutil.tcl
dict set portparse::_directives post-destroot                                            {sets {post-destroot} category phase}         ;# portutil.tcl
dict set portparse::_directives post-extract                                             {sets {post-extract} category phase}         ;# portutil.tcl
dict set portparse::_directives post-fetch                                               {sets {post-fetch} category phase}         ;# portutil.tcl
dict set portparse::_directives post-install                                             {sets {post-install} category phase}         ;# portutil.tcl
dict set portparse::_directives post-patch                                               {sets {post-patch} category phase}         ;# portutil.tcl
dict set portparse::_directives post-test                                                {sets {post-test} category phase}         ;# portutil.tcl
dict set portparse::_directives post-uninstall                                           {sets {post-uninstall} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-activate                                             {sets {pre-activate} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-build                                                {sets {pre-build} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-checksum                                             {sets {pre-checksum} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-configure                                            {sets {pre-configure} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-deactivate                                           {sets {pre-deactivate} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-destroot                                             {sets {pre-destroot} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-extract                                              {sets {pre-extract} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-fetch                                                {sets {pre-fetch} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-install                                              {sets {pre-install} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-patch                                                {sets {pre-patch} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-test                                                 {sets {pre-test} category phase}         ;# portutil.tcl
dict set portparse::_directives pre-uninstall                                            {sets {pre-uninstall} category phase}         ;# portutil.tcl
dict set portparse::_directives prefix                                                   {sets {prefix} category metadata}      ;# portmain.tcl
dict set portparse::_directives provides                                                 {sets {provides} category metadata}      ;# portmain.tcl
dict set portparse::_directives reload.asroot                                            {sets {reload.asroot} category phase}         ;# portreload.tcl
dict set portparse::_directives replaced_by                                              {sets {replaced_by} category dependency}    ;# portmain.tcl
dict set portparse::_directives revision                                                 {sets {revision} category identity}      ;# portmain.tcl
dict set portparse::_directives source_date_epoch                                        {sets {source_date_epoch} category metadata}      ;# portmain.tcl
dict set portparse::_directives sources_conf                                             {sets {sources_conf} category metadata}      ;# portmain.tcl
dict set portparse::_directives startupitem.autostart                                    {sets {startupitem.autostart} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.create                                       {sets {startupitem.create} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.custom_file                                  {sets {startupitem.custom_file} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.daemondo.verbosity                           {sets {startupitem.daemondo.verbosity} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.debug                                        {sets {startupitem.debug} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.executable                                   {sets {startupitem.executable} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.group                                        {sets {startupitem.group} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.init                                         {sets {startupitem.init} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.install                                      {sets {startupitem.install} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.location                                     {sets {startupitem.location} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.logevents                                    {sets {startupitem.logevents} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.logfile                                      {sets {startupitem.logfile} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.logfile.stderr                               {sets {startupitem.logfile.stderr} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.name                                         {sets {startupitem.name} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.netchange                                    {sets {startupitem.netchange} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.pidfile                                      {sets {startupitem.pidfile} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.plist                                        {sets {startupitem.plist} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.requires                                     {sets {startupitem.requires} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.restart                                      {sets {startupitem.restart} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.start                                        {sets {startupitem.start} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.stop                                         {sets {startupitem.stop} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.type                                         {sets {startupitem.type} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.uniquename                                   {sets {startupitem.uniquename} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitem.user                                         {sets {startupitem.user} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives startupitems                                             {sets {startupitems} category phase}         ;# portstartupitem.tcl
dict set portparse::_directives subport                                                  {sets {subport} category phase}         ;# portutil.tcl
dict set portparse::_directives supported_archs                                          {sets {supported_archs} category metadata}      ;# portmain.tcl
dict set portparse::_directives svn.args                                                 {sets {svn.args} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.cmd                                                  {sets {svn.cmd} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.dir                                                  {sets {svn.dir} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.env                                                  {sets {svn.env} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.method                                               {sets {svn.method} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.nice                                                 {sets {svn.nice} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.post_args                                            {sets {svn.post_args} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.pre_args                                             {sets {svn.pre_args} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.revision                                             {sets {svn.revision} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.type                                                 {sets {svn.type} category source}        ;# portfetch.tcl
dict set portparse::_directives svn.url                                                  {sets {svn.url} category source}        ;# portfetch.tcl
dict set portparse::_directives test                                                     {sets {test} category phase}         ;# porttest.tcl (phase-override body)
dict set portparse::_directives test.args                                                {sets {test.args} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.asroot                                              {sets {test.asroot} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.cmd                                                 {sets {test.cmd} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.dir                                                 {sets {test.dir} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.env                                                 {sets {test.env} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.ignore_archs                                        {sets {test.ignore_archs} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.nice                                                {sets {test.nice} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.post_args                                           {sets {test.post_args} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.pre_args                                            {sets {test.pre_args} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.run                                                 {sets {test.run} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.target                                              {sets {test.target} category build-config}  ;# porttest.tcl
dict set portparse::_directives test.type                                                {sets {test.type} category build-config}  ;# porttest.tcl
dict set portparse::_directives uninstall.asroot                                         {sets {uninstall.asroot} category phase}         ;# portuninstall.tcl
dict set portparse::_directives universal_possible                                       {sets {universal_possible} category metadata}      ;# portmain.tcl
dict set portparse::_directives universal_variant                                        {sets {universal_variant} category metadata}      ;# portmain.tcl
dict set portparse::_directives unload.asroot                                            {sets {unload.asroot} category phase}         ;# portunload.tcl
dict set portparse::_directives use_7z                                                   {sets {use_7z} category source}        ;# portextract.tcl
dict set portparse::_directives use_autoconf                                             {sets {use_autoconf} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives use_automake                                             {sets {use_automake} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives use_autoreconf                                           {sets {use_autoreconf} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives use_build                                                {sets {use_build} category build-config}  ;# portbuild.tcl
dict set portparse::_directives use_bzip2                                                {sets {use_bzip2} category source}        ;# portextract.tcl
dict set portparse::_directives use_bzr                                                  {sets {use_bzr} category source}        ;# portfetch.tcl
dict set portparse::_directives use_configure                                            {sets {use_configure} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives use_cvs                                                  {sets {use_cvs} category source}        ;# portfetch.tcl
dict set portparse::_directives use_destroot                                             {sets {use_destroot} category build-config}  ;# portdestroot.tcl
dict set portparse::_directives use_dmg                                                  {sets {use_dmg} category source}        ;# portextract.tcl
dict set portparse::_directives use_extract                                              {sets {use_extract} category source}        ;# portextract.tcl
dict set portparse::_directives use_lzip                                                 {sets {use_lzip} category source}        ;# portextract.tcl
dict set portparse::_directives use_lzma                                                 {sets {use_lzma} category source}        ;# portextract.tcl
dict set portparse::_directives use_parallel_build                                       {sets {use_parallel_build} category build-config}  ;# portbuild.tcl
dict set portparse::_directives use_patch                                                {sets {use_patch} category source}        ;# portpatch.tcl
dict set portparse::_directives use_svn                                                  {sets {use_svn} category source}        ;# portfetch.tcl
dict set portparse::_directives use_tar                                                  {sets {use_tar} category source}        ;# portextract.tcl
dict set portparse::_directives use_test                                                 {sets {use_test} category build-config}  ;# porttest.tcl
dict set portparse::_directives use_xcode                                                {sets {use_xcode} category metadata}      ;# portmain.tcl
dict set portparse::_directives use_xmkmf                                                {sets {use_xmkmf} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives use_xz                                                   {sets {use_xz} category source}        ;# portextract.tcl
dict set portparse::_directives use_zip                                                  {sets {use_zip} category source}        ;# portextract.tcl
dict set portparse::_directives variant                                                  {sets {variant} category phase}         ;# portutil.tcl
dict set portparse::_directives version                                                  {sets {version} category identity}      ;# portmain.tcl
dict set portparse::_directives worksrcdir                                               {sets {worksrcdir} category metadata}      ;# portmain.tcl
dict set portparse::_directives xmkmf.args                                               {sets {xmkmf.args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.cmd                                                {sets {xmkmf.cmd} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.dir                                                {sets {xmkmf.dir} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.env                                                {sets {xmkmf.env} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.nice                                               {sets {xmkmf.nice} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.post_args                                          {sets {xmkmf.post_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.pre_args                                           {sets {xmkmf.pre_args} category build-config}  ;# portconfigure.tcl
dict set portparse::_directives xmkmf.type                                               {sets {xmkmf.type} category build-config}  ;# portconfigure.tcl

# --------------------------------------------------------------------------
# target_provides-sourced directives. Each call to `target_provides` in
# port1.0 creates a target-override form (NAME {body}) and pre-/post-
# hooks (pre-NAME {body}, post-NAME {body}). configure/build/destroot/
# test live with the other phase directives above; distfiles lives in
# the source category above (its data form wins; the target-override
# form stays out of body_policy because its braced arg is a distfile
# list, not Tcl code). The remaining 18 targets and their pre-/post-
# pairs are enumerated here.
#
# If a future port1.0 commit adds a new `target_provides` call, the
# drift test flags it with a precise "registered in <file>:<line> via
# 'target_provides'" message.
# --------------------------------------------------------------------------

# Target-override bodies.
dict set portparse::_directives activate       {sets {activate} category phase}       ;# portactivate.tcl (target_provides)
dict set portparse::_directives bump           {sets {bump} category phase}           ;# portbump.tcl (target_provides)
dict set portparse::_directives checksum       {sets {checksum} category phase}       ;# portchecksum.tcl (target_provides)
dict set portparse::_directives clean          {sets {clean} category phase}          ;# portclean.tcl (target_provides)
dict set portparse::_directives deactivate     {sets {deactivate} category phase}     ;# portdeactivate.tcl (target_provides)
dict set portparse::_directives distcheck      {sets {distcheck} category phase}      ;# portdistcheck.tcl (target_provides)
dict set portparse::_directives extract        {sets {extract} category phase}        ;# portextract.tcl (target_provides)
dict set portparse::_directives fetch          {sets {fetch} category phase}          ;# portfetch.tcl (target_provides)
dict set portparse::_directives install        {sets {install} category phase}        ;# portinstall.tcl (target_provides)
dict set portparse::_directives lint           {sets {lint} category phase}           ;# portlint.tcl (target_provides)
dict set portparse::_directives livecheck      {sets {livecheck} category phase}      ;# portlivecheck.tcl (target_provides)
dict set portparse::_directives load           {sets {load} category phase}           ;# portload.tcl (target_provides)
dict set portparse::_directives main           {sets {main} category phase}           ;# portmain.tcl (target_provides)
dict set portparse::_directives mirror         {sets {mirror} category phase}         ;# portmirror.tcl (target_provides)
dict set portparse::_directives patch          {sets {patch} category phase}          ;# portpatch.tcl (target_provides)
dict set portparse::_directives reload         {sets {reload} category phase}         ;# portreload.tcl (target_provides)
dict set portparse::_directives uninstall      {sets {uninstall} category phase}      ;# portuninstall.tcl (target_provides)
dict set portparse::_directives unload         {sets {unload} category phase}         ;# portunload.tcl (target_provides)

# pre-/post- hooks for the additional 11 targets (the 12 pipeline phases
# are covered by the pre-/post- block above).
dict set portparse::_directives pre-bump          {sets {pre-bump} category phase}          ;# portbump.tcl
dict set portparse::_directives post-bump         {sets {post-bump} category phase}         ;# portbump.tcl
dict set portparse::_directives pre-clean         {sets {pre-clean} category phase}         ;# portclean.tcl
dict set portparse::_directives post-clean        {sets {post-clean} category phase}        ;# portclean.tcl
dict set portparse::_directives pre-distcheck     {sets {pre-distcheck} category phase}     ;# portdistcheck.tcl
dict set portparse::_directives post-distcheck    {sets {post-distcheck} category phase}    ;# portdistcheck.tcl
dict set portparse::_directives pre-distfiles     {sets {pre-distfiles} category phase}     ;# portdistfiles.tcl
dict set portparse::_directives post-distfiles    {sets {post-distfiles} category phase}    ;# portdistfiles.tcl
dict set portparse::_directives pre-lint          {sets {pre-lint} category phase}          ;# portlint.tcl
dict set portparse::_directives post-lint         {sets {post-lint} category phase}         ;# portlint.tcl
dict set portparse::_directives pre-livecheck     {sets {pre-livecheck} category phase}     ;# portlivecheck.tcl
dict set portparse::_directives post-livecheck    {sets {post-livecheck} category phase}    ;# portlivecheck.tcl
dict set portparse::_directives pre-load          {sets {pre-load} category phase}          ;# portload.tcl
dict set portparse::_directives post-load         {sets {post-load} category phase}         ;# portload.tcl
dict set portparse::_directives pre-main          {sets {pre-main} category phase}          ;# portmain.tcl
dict set portparse::_directives post-main         {sets {post-main} category phase}         ;# portmain.tcl
dict set portparse::_directives pre-mirror        {sets {pre-mirror} category phase}        ;# portmirror.tcl
dict set portparse::_directives post-mirror       {sets {post-mirror} category phase}       ;# portmirror.tcl
dict set portparse::_directives pre-reload        {sets {pre-reload} category phase}        ;# portreload.tcl
dict set portparse::_directives post-reload       {sets {post-reload} category phase}       ;# portreload.tcl
dict set portparse::_directives pre-unload        {sets {pre-unload} category phase}        ;# portunload.tcl
dict set portparse::_directives post-unload       {sets {post-unload} category phase}       ;# portunload.tcl

# --------------------------------------------------------------------------
# portparse::categories — ordered, closed enum. Expanding it is a breaking
# change: ship under a new package-provide version if it becomes
# necessary.
# --------------------------------------------------------------------------

proc portparse::categories {} {
    variable _categories
    # Return a fresh copy so mutation by the caller does not affect
    # subsequent calls.
    return [lrange $_categories 0 end]
}
