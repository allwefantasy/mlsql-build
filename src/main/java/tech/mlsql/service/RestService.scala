package tech.mlsql.service

import java.lang.reflect.Proxy
import java.util.UUID

import com.alibaba.dubbo.rpc.protocol.rest.RestClientProxy
import com.google.common.cache.{CacheBuilder, CacheLoader}
import net.csdn.ServiceFramwork
import net.csdn.annotation.Param
import net.csdn.annotation.rest.At
import net.csdn.common.settings.Settings
import net.csdn.modules.http.RestRequest.Method.{GET, POST}
import net.csdn.modules.threadpool.DefaultThreadPoolService
import net.csdn.modules.transport.{DefaultHttpTransportService, HttpTransportService}

/**
  * 2019-01-03 WilliamZhu(allwefantasy@gmail.com)
  */
object RestService {


  private final val settings: Settings = ServiceFramwork.injector.getInstance(classOf[Settings])
  private final val transportService: HttpTransportService = new DefaultHttpTransportService(new DefaultThreadPoolService(settings), settings)
  private val cache = CacheBuilder.newBuilder()
    .maximumSize(10000)
    .build(
      new CacheLoader[String, BackendService]() {
        override def load(key: String): BackendService = {
          BackendRestClient.buildClient[BackendService](key, transportService)
        }
      })

  val auth_secret = {
    settings.get("auth_secret", UUID.randomUUID().toString)
  }
  println(s"auth_secret:${auth_secret}")

  def client(url: String): BackendService = cache.get(url)
}

object BackendRestClient {


  def buildClient[T](url: String, transportService: HttpTransportService)(implicit manifest: Manifest[T]): T = {
    val restClientProxy = new RestClientProxy(transportService)
    if (url.startsWith("http:")) {
      restClientProxy.target(url)
    } else {
      restClientProxy.target("http://" + url + "/")
    }
    val clazz = manifest.runtimeClass
    Proxy.newProxyInstance(clazz.getClassLoader, Array(clazz), restClientProxy).asInstanceOf[T]
  }
}

trait BackendService {
  @At(path = Array("/run/script"), types = Array(GET, POST))
  def runScript(@Param("sql") sql: String): HttpTransportService.SResponse

  @At(path = Array("/run/script"), types = Array(POST))
  def runScript(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/run/sql"), types = Array(GET, POST))
  def runSQL(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/backend/list"), types = Array(GET, POST))
  def backendList(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/backend/add"), types = Array(GET, POST))
  def backendAdd(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/backend/remove"), types = Array(GET, POST))
  def backendRemove(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/backend/tags/update"), types = Array(GET, POST))
  def backendTagsUpdate(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/backend/name/check"), types = Array(GET, POST))
  def backendNameCheck(params: Map[String, String]): HttpTransportService.SResponse

  @At(path = Array("/backend/list/names"), types = Array(GET, POST))
  def backendListNames(params: Map[String, String]): HttpTransportService.SResponse
}
