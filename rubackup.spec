Name:               rubackup
Summary:            Ruby based backup application for Linux
Version:            %{progversion}
Release:            %{progrelease}%{dist}
Source0:            %{name}-%{version}.tar.gz
BuildArch:          noarch
License:            GPLv2
Group:              Utilities
Requires:           ruby >= 1.9
BuildRequires:      tar, rsync
Requires:           rubygem(aws-sdk-core) >= 2.1.0
Requires:           rubygem(aws-sdk-resources) >= 2.1.0

%define deploydir   /opt/rubackup
%define configdir   /etc/rubackup.d

%description
Ruby based backup application for Linux

%prep
%setup -q

%build

%install
mkdir -p ${RPM_BUILD_ROOT}%{deploydir} ${RPM_BUILD_ROOT}%{configdir}
rsync -a ${RPM_BUILD_DIR}/rubackup-%{version}/src/ ${RPM_BUILD_ROOT}%{deploydir}/

%files
%defattr(-,root,root,-)
%{configdir}
%{deploydir}

%changelog

* Sun May 15 2016 Francois Dupoux - 0.2.2-1
- Support for long EC2 instance IDs

* Tue Dec 01 2015 Francois Dupoux - 0.2.1-1
- Fixed upload of large files to AWS S3

* Sun Nov 29 2015 Francois Dupoux - 0.2.0-1
- Upgraded to AWS SDK version 2

* Sun Mar 29 2015 Francois Dupoux - 0.1.1-1
- Fixed bug in scheduling

* Sun Jan 25 2015 Francois Dupoux - 0.1.0-1
- First public release
