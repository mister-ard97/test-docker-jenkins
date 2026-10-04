# DevOps Technical Test - Shift Engineer

## Environment
- OS: Windows 11, Docker Desktop v4.38.0 (WSL2)
- Go: 1.27.1 (go.mod dan image builder golang:1.27.1-alpine)
- Jenkins: 2.479.2, container lokal di port 8081 (jenkins/Dockerfile)
- Registry: Docker Hub, Erlnggss/devops-app

## Isi repo
| File | Fungsi |
|---|---|
| main.go, main_test.go | Aplikasi dan unit test |
| Dockerfile | Multi-stage build: base, test, build, scratch |
| scripts/swap-binary.sh | Hotfix: ganti binary tanpa rebuild, dengan rollback |
| Jenkinsfile | Pipeline: Checkout, Test, Build Image, Push, Deploy |
| jenkins/Dockerfile | Image Jenkins dengan Docker CLI |
| docs/ | Log dan screenshot bukti |

## Part I - Build
Dockerfile: [Dockerfile](Dockerfile)

bash
docker build --build-arg VERSION=1.0.0 -t devops-app:1.0.0 .
docker images devops-app

IMAGE                    ID             DISK USAGE   CONTENT SIZE
devops-app:1.0.0         a9f4b44467d2   8.35MB       2.51MB
devops-app:1.0.1-04c1687 9182ed350f97   8.36MB       2.52MB

Alasan base image: Menggunakan golang:1.27.1-alpine untuk tahap kompilasi/pembentukan aplikasi karena ringan dan sudah memiliki perkakas Go yang lengkap. Pada tahap akhir image runner, digunakan scratch (image kosong) sehingga container berukuran sangat kecil dan bebas dari kerentanan OS.
Kenapa ukurannya begitu: Ukuran image akhir sangat kecil (~8.35 MB) karena hanya berisi satu file executable biner Go hasil kompilasi statis (CGO_ENABLED=0), tanpa menyertakan OS Linux, shell, maupun library pendukung yang tidak diperlukan.

## Part II - Deploy dan hotfix

Bash
docker run -d --name devops-app -p 8080:8080 --restart unless-stopped devops-app:1.0.0
CGO_ENABLED=0 GOOS=linux go build -trimpath \
  -ldflags "-s -w -X main.version=1.0.1-hotfix" -o build/myapp .
docker cp devops-app:/app/myapp build/myapp.prev
docker cp build/myapp devops-app:/app/myapp
docker restart devops-app
# atau: bash scripts/swap-binary.sh devops-app build/myapp 1.0.1-hotfix

curl sebelum dan sesudah:

Sebelum: Hello, DevOps! version=1.0.0

Sesudah: Hello, DevOps! version=1.0.1-hotfix

Downtime: Jeda yang terjadi sangat minimal (orde milidetik) hanya saat proses restart/penggantian biner pada container.
Pendekatan yang dipilih: Menggunakan binary hot-swap langsung ke container yang berjalan tanpa perlu melakukan rebuild image dari awal, sehingga mempercepat proses critical bugfix di lingkungan produksi.

## Part III - CI/CD Jenkins

Pipeline: Jenkinsfile

Pipeline Status: Sukses menjalankan seluruh stage (Checkout, Test, Build Image, Push, Deploy).

Test Failure Handling: Pipeline dikonfigurasi untuk langsung gagal (abort/stop) jika unit test pada stage Test gagal, sehingga mencegah image yang rusak ter-deploy.

Hasil Akhir Endpoint: curl http://localhost:8080/ menghasilkan Hello, DevOps! version=1.0.1-<commit-hash>.