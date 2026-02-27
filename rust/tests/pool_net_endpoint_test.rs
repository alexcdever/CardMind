// input: PoolEndpoint 构建与连接
// output: 端点可启动并建立连接
// pos: 组网端点测试（修改本文件需同步更新文件头与所属 DIR.md）
use cardmind_rust::net::endpoint::build_test_endpoints;
use std::error::Error;
use std::time::Duration;

#[tokio::test]
async fn it_should_connect_two_endpoints() -> Result<(), Box<dyn std::error::Error>> {
    let (a, b) = build_test_endpoints().await?;
    let addr = b.wait_for_addr(Duration::from_secs(10)).await?;
    let accept_task = async {
        let incoming = b.inner().accept().await.ok_or("endpoint closed")?;
        let accepting = incoming.accept()?;
        let conn = accepting.await?;
        Ok::<_, Box<dyn Error>>(conn)
    };
    let connect_task = async {
        a.connect(addr)
            .await
            .map_err(|err| Box::new(err) as Box<dyn Error>)
    };
    let (connect_res, accept_res) = tokio::join!(connect_task, accept_task);
    connect_res?;
    accept_res?;
    Ok(())
}
