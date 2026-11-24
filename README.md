# 🏠 Ansible 기반 Kubernetes Worker 노드 설정 자동화

기존 kubeadm 클러스터에 Ubuntu 온프레미스 서버를 Worker로 추가하기 위한 Ansible 프로젝트입니다. Ansible Controller는 Docker Compose 컨테이너에서 실행하며, 관리 대상 서버에는 Ansible을 설치하지 않습니다.

> ⚠️ **운영 전에 확인하세요**
>
> 저장소의 <code>inventory/example/</code>은 문서용 주소와 예시 호스트명만 사용합니다. 실제 서버 설정으로 복사·수정하기 전에는 사용할 수 없습니다. Join은 API 경로, 노드 주소, Calico 및 네트워크 확인값이 충족되지 않으면 중단됩니다.

## 🧭 한눈에 보기

| 구분 | 내용 |
|---|---|
| 목적 | 기존 kubeadm 클러스터에 Worker 한 대씩 추가 |
| 실행 위치 | Docker Engine이 설치된 Controller에서 Docker Compose로 실행 |
| 대상 OS | Ubuntu 24.04, x86_64 (예시 인벤토리 기본값) |
| 기본 구성 | Kubernetes 1.37.0 · containerd 2.3.6 · runc 1.5.2 |
| 공개 인벤토리 | 문서용 주소와 <code>.example.invalid</code> 호스트명만 포함 |
| 운영 인벤토리 | <code>inventory/production/</code>에 생성하며 Git 및 Docker 빌드 컨텍스트에서 제외 |

## 🔄 실행 단계

| 단계 | Playbook | 동작 |
|---|---|---|
| 1. 사전 점검 | [preflight.yml](playbooks/preflight.yml) | Worker와 Control Plane의 OS·리소스·기존 상태·API 경로·인증서·버전 확인. 호스트 설정은 변경하지 않음 |
| 2. Worker 준비 | [prepare-worker.yml](playbooks/prepare-worker.yml) | 선택한 Worker에 커널 설정, containerd, kubeadm·kubelet 및 Node IP 구성 |
| 3. 클러스터 가입 | [join-worker.yml](playbooks/join-worker.yml) | Control Plane에서 단기 토큰을 발급하고 선택한 Worker 한 대를 가입 |
| 4. 가입 확인 | [verify-worker.yml](playbooks/verify-worker.yml) | Node 상태와 kubelet, Calico, CSI, kube-proxy 확인 |

~~~mermaid
flowchart LR
  controller["Controller<br/>Docker Compose + Ansible"]
  cp["Kubernetes Control Plane"]
  worker["선택한 Worker"]

  controller -->|"SSH · SSH Agent"| cp
  controller -->|"SSH · SSH Agent"| worker
  cp -->|"15분 유효 토큰 발급"| worker
  worker -->|"kubeadm join · TCP 6443"| cp
  cp -.->|"kubelet API · TCP 10250"| worker
~~~

## 🛡️ 안전장치와 범위

| 항목 | 동작 |
|---|---|
| 대상 제한 | 사전 점검·가입·검증은 한 번에 Worker 한 대만 처리합니다. 실행 때 <code>--limit</code>으로 SSH 별칭 하나를 지정해야 합니다. |
| 토큰 보호 | Join 시 15분 만료 토큰을 사용하고 토큰과 Join 명령은 Ansible 출력에서 숨깁니다(<code>no_log</code>). |
| 기존 상태 보호 | 이미 Kubernetes 상태나 관리되지 않는 containerd가 있으면 자동 초기화·교체하지 않고 멈춥니다. <code>kubeadm reset</code>이나 자동 재가입을 실행하지 않습니다. |
| 네트워크 | UFW, Netplan, 라우터, 스위치, Wi-Fi, Docker 라우팅을 변경하지 않습니다. |
| Calico | Operator나 Calico 설정을 변경하지 않습니다. 주소 자동 감지 결과를 사람이 확인해야 합니다. |
| 클러스터 범위 | Control Plane의 Kubernetes 패키지나 서비스를 설치·업그레이드하지 않습니다. 앱 배포, 스토리지, kubeconfig, 노드 제거도 관리하지 않습니다. |

## 📦 예시 버전

다음은 저장소 예시 인벤토리의 기본값입니다. 실제 사용 전 Control Plane과 대상 서버에 맞는지 확인하세요.

| 구성 요소 | 기본 버전 | 참고 |
|---|---:|---|
| Ansible Core | 2.22.0 | Controller 컨테이너에 설치 |
| Python | 3.14 | Controller 이미지 기준 |
| <code>ansible.posix</code> | 2.2.2 | Ansible Collection |
| Kubernetes 패키지 | 1.37.0 | stable v1.37 저장소 사용 |
| containerd | 2.3.6 | 업스트림 릴리스 체크섬 확인 |
| runc | 1.5.2 | 업스트림 바이너리 체크섬 확인 |

Kubernetes 패키지는 설치 후 해당 버전으로 고정됩니다. 기존 containerd 바이너리나 설정이 감지되면 덮어쓰지 않고 중단합니다.

## ✅ 시작 전 준비

- Controller에 Docker Engine과 Docker Compose 플러그인을 설치합니다.
- 적절한 키를 노트북의 <code>ssh-agent</code>에 등록합니다.
- Controller 컨테이너에서 해석할 SSH 별칭과 <code>known_hosts</code> 항목을 준비합니다.
- SSH 사용자에게 대상 서버에서 사용할 sudo 암호를 준비합니다. 암호를 인벤토리나 Git에 저장하지 마세요.
- Controller 컨테이너에서 SSH 대상에 접근할 수 있고, Worker에서 Kubernetes API에 접근할 수 있는지 확인합니다.

<code>compose.yml</code>은 SSH 설정과 <code>known_hosts</code>를 읽기 전용으로 연결하고, 인증에는 전달된 SSH Agent를 사용합니다. 개인키 파일은 컨테이너에 마운트하지 않으며 SSH 호스트 키 검사를 유지합니다. Controller는 Docker 기본 bridge 네트워크를 사용하고, 이 프로젝트는 호스트나 Docker 라우팅을 변경하지 않습니다.

## 🗂️ 운영 인벤토리 준비

기본 인벤토리는 안전한 예시인 <code>inventory/example/hosts.yml</code>을 가리킵니다. 예시 주소는 라우팅용이 아닌 예약 문서 대역이며, SSH 호스트명은 <code>.example.invalid</code>입니다.

예시를 로컬 운영 인벤토리로 복사합니다.

~~~bash
mkdir -p inventory/production
cp -a inventory/example/. inventory/production/
~~~

| 파일 | 수정할 내용 |
|---|---|
| <code>hosts.yml</code> | Control Plane 및 Worker 호스트 별칭. <code>control_plane</code>, <code>onprem_workers</code> 그룹은 유지 |
| <code>host_vars/*.yml</code> | Controller에서 접속 가능한 SSH 별칭을 <code>ansible_host</code>에 지정 |
| <code>group_vars/all.yml</code> | 기존 클러스터와 일치하는 API 주소·포트 및 Kubernetes 버전 |
| <code>group_vars/onprem_workers.yml</code> | Worker의 실제 Node IP와 Kubernetes Node 이름 |

<code>inventory/production/</code>은 <code>.gitignore</code>와 <code>.dockerignore</code>에서 제외됩니다. 로컬 실제 인벤토리와 비밀 파일을 저장소에 추가하지 마세요. Ansible Vault를 사용하는 경우 암호 파일도 저장소 밖에 둡니다.

## 🌐 가입 전 네트워크 확인

아래 경로와 주소는 자동으로 설정하지 않습니다. Join 전에 현재 환경에서 직접 확인하고, 확인한 항목만 로컬 Worker 인벤토리에서 허용값으로 바꾸세요.

| 확인 항목 | 통신 방향 | 확인할 값 |
|---|---|---|
| Kubernetes API | Worker → API 서버, TCP 6443 | 연결 가능 여부와 API 인증서 SAN에 API 주소가 있는지 |
| kubelet API | Control Plane → Worker, TCP 10250 | Control Plane에서 Worker 주소에 연결되는지 |
| Calico VXLAN | 노드 간, UDP 4789 | 실제 Calico 모드와 노드 간 경로 |
| Calico Node 주소 | Calico Operator 주소 자동 감지 | Worker가 사용할 주소가 <code>kubernetes_node_ip</code>와 일치하는지 |
| Typha | Typha를 쓰는 경우 Worker → Typha, TCP 5473 | Typha 배포 여부와 사용 시 연결 가능 여부 |

예시 인벤토리의 확인 변수는 모두 기본값이 <code>false</code>입니다.

| 확인 후 변경할 변수 | 확인 내용 |
|---|---|
| <code>calico_node_addressing_verified</code> | Calico가 선택할 Worker 주소 확인 |
| <code>control_plane_to_worker_10250_verified</code> | TCP 10250 경로 확인 |
| <code>node_to_node_vxlan_4789_verified</code> | VXLAN UDP 4789 경로 확인 |
| <code>calico_typha_deployment_checked</code> | Typha 배포 여부 확인 |
| <code>calico_typha_in_use</code>, <code>calico_typha_5473_verified</code> | Typha가 사용될 때 TCP 5473 경로 확인 |

경로가 확인되지 않았거나 사전 점검이 실패하면 Join 단계로 진행하지 마세요. 방화벽·라우팅·Calico 문제는 이 프로젝트 밖에서 해결해야 합니다.

## 🚀 실행 방법

프로젝트 루트에서 실행합니다. 아래 명령의 <code>worker-01</code>은 운영 인벤토리에 등록한 Worker SSH 별칭으로 바꿔 사용하세요. 배포 명령은 실수 방지를 위해 로컬 운영 인벤토리를 명시합니다.

### 1. Controller 이미지 준비 및 SSH 확인

~~~bash
docker compose build ansible
docker compose run --rm ansible ansible all -i inventory/production/hosts.yml -m ping
~~~

### 2. 읽기 전용 사전 점검

~~~bash
docker compose run --rm ansible ansible-playbook \
  -i inventory/production/hosts.yml \
  playbooks/preflight.yml \
  --limit worker-01 \
  --ask-become-pass
~~~

사전 점검이 실패하면 원인을 확인하고 먼저 해결합니다. 점검을 우회해 다음 단계로 진행하지 마세요.

### 3. Worker 준비

이 단계부터 선택한 Worker의 OS 설정과 패키지가 변경됩니다.

~~~bash
docker compose run --rm ansible ansible-playbook \
  -i inventory/production/hosts.yml \
  playbooks/prepare-worker.yml \
  --limit worker-01 \
  --ask-become-pass
~~~

### 4. Worker 가입

네트워크 경로, API 인증서, Node IP, Calico 주소를 확인하고 로컬 인벤토리의 확인 변수를 설정한 뒤 실행합니다.

~~~bash
docker compose run --rm ansible ansible-playbook \
  -i inventory/production/hosts.yml \
  playbooks/join-worker.yml \
  --limit worker-01 \
  --ask-become-pass
~~~

### 5. 가입 후 읽기 전용 확인

~~~bash
docker compose run --rm ansible ansible-playbook \
  -i inventory/production/hosts.yml \
  playbooks/verify-worker.yml \
  --limit worker-01 \
  --ask-become-pass
~~~

추가 Worker는 호스트와 <code>host_vars</code>를 한 대씩 등록합니다. 최초 준비와 가입은 매번 Worker 한 대만 대상으로 실행하세요.

## 📁 저장소 구성

~~~text
.
├── Dockerfile
├── compose.yml
├── ansible.cfg
├── requirements-controller.txt
├── requirements.yml
├── inventory/
│   └── example/
├── playbooks/
└── roles/
~~~

기본 Inventory는 문서용 예시입니다. 실제 배포 명령에는 로컬 인벤토리 경로를 <code>-i inventory/production/hosts.yml</code>로 지정해야 합니다.
