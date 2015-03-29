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

* Sun Jan 25 2015 Francois Dupoux - 0.1.0-1
- First public release
